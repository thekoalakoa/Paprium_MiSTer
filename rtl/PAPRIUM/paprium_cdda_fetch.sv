// ---------------------------------------------------------------------------
// Paprium CDDA fetch - SD-slot producer (S2: stock-Main SD streaming, hps_io slot 1).
//
// Replaces the DDRAM read master of the earlier build. paprium.pcm (the ORIGINAL
// 569,380,864 B PPAD file) is mounted by stock Main on hps_io disk slot 1 (the
// OSD entry "SC1,PCM,..."; the save RAM stays on slot 0). This module asks Main
// for 4 KiB at a time (8 x 512 B sectors, sd_blk_cnt=7) and writes the words that
// come back on sd_buff_dout straight into the existing IMA ring (paprium_cdda_buf)
// through the unchanged buf_wr_* / Gray chunk-counter interface.
//
// Header handling (same PPAD rules as before, now read through the SD slot):
//   - magic/version/rate/channels/block/ntracks = first 24 B  (sector 0, 1 sector)
//   - per track entry at 0x18+16*track (start, hi, len, samples): read 2 sectors
//     (an entry can straddle a 512 B boundary, e.g. track 30), capture 8 words.
// Everything is requested only from this module's FSM; the 68k side never waits
// on it: no output of this module is a wait/ready for the CPU. An empty ring plays
// silence in paprium_cdda_play (unchanged). SD timeouts (~1.25 s) end the attempt.
//
// Mount handling: pcm_mount_ev (img_mounted[1] rising) clears blob_ok and re-checks
// the header; pcm_present (latched image size != 0 in MegaDrive.sv) is a LEVEL, so a
// pcm mounted by Main at core start (before the ROM / before paprium_active) is
// checked as soon as this module leaves reset.
//
// Indicator (info_req/info -> hps_io -> Main shows the CONF_STR "I" string):
//   1 pcm mounted + header valid, 2 pcm mounted but invalid, 3 pcm ejected,
//   4 ring ran dry while a track was playing (after the first chunk landed).
//
// Clock: clk_sys (same domain as paprium_cdda_buf / play and hps_io).
// ---------------------------------------------------------------------------

module paprium_cdda_fetch #(
	parameter        CHUNK_BYTES    = 4096,
	parameter        NUM_CHUNKS     = 4,
	parameter        CHUNK_W        = $clog2(NUM_CHUNKS),
	// timer widths @53.69 MHz (overridable only so a simulation can run fast; the build uses the defaults)
	parameter        TMO_W          = 26,   // SD request timeout 2^26 clk = 1.25 s
	parameter        SETTLE_W       = 21,   // post-abort quiet time 2^21 clk = 39 ms
	parameter        HOLD_W         = 27    // OSD message spacing 2^27 clk = 2.5 s (4 = 5 s)
) (
	input  wire        clk,
	input  wire        reset,

	input  wire        track_request,   // one-cycle pulse (clk_sys)
	input  wire  [7:0] track_num,
	input  wire        track_loop,
	input  wire        stop_request,

	// pcm image on hps_io slot 1
	input  wire        pcm_mount_ev,    // pulse: img_mounted[1] rising edge
	input  wire        pcm_present,     // level: image size latched at the last slot-1 mount != 0
	input  wire [31:0] pcm_size_lo,     // image size, low 32 bits
	input  wire        pcm_size_hi,     // |image size[63:32]  (treated as "large")

	// hps_io SD block interface, slot 1
	output reg  [31:0] sd_lba,
	output reg   [5:0] sd_blk_cnt,      // blocks-1 (512 B sectors)
	output reg         sd_rd,
	input  wire        sd_ack,
	input  wire [11:0] sd_buff_addr,    // word index inside the transfer
	input  wire [15:0] sd_buff_dout,
	input  wire        sd_buff_wr,

	// Direct write into paprium_cdda_buf
	output reg        buf_wr_en,
	output reg [12:0] buf_wr_addr,   // 16-bit word index within the ring
	output reg [15:0] buf_wr_data,

	input  wire [CHUNK_W:0] rd_chunk_gray,
	output reg  [CHUNK_W:0] wr_chunk_gray,

	output reg         playing,
	output reg   [7:0] current_track,
	output wire        blob_ok,

	// indicator
	input  wire [15:0] underruns,
	output reg         info_req,
	output reg   [7:0] info
);

	// ---- header capture ---------------------------------------------------
	reg [15:0] hdr [0:11];

	wire        ppad_magic = (hdr[0] == 16'h5050) && (hdr[1] == 16'h4441);
	wire [31:0] f_version  = {hdr[3],  hdr[2]};
	wire [31:0] f_rate     = {hdr[5],  hdr[4]};
	wire [31:0] f_chans    = {hdr[7],  hdr[6]};
	wire [31:0] f_blk      = {hdr[9],  hdr[8]};
	wire [31:0] f_ntracks  = {hdr[11], hdr[10]};

	wire blob_valid = ppad_magic
	               && (f_version == 32'd1)
	               && (f_rate    == 32'd48000)
	               && (f_chans   == 32'd2)
	               && (f_blk     == 32'd505)
	               && (f_ntracks >= 32'd64);

	wire [31:0] hdr_start  = {hdr[1], hdr[0]};
	wire [31:0] hdr_off_hi = {hdr[3], hdr[2]};
	wire [31:0] hdr_len    = {hdr[5], hdr[4]};
	wire [31:0] hdr_smpls  = {hdr[7], hdr[6]};

	// track entry must lie inside the mounted image and start on a sector boundary
	wire [32:0] hdr_end    = {1'b0, hdr_start} + {1'b0, hdr_len};
	wire        hdr_inside = pcm_size_hi || (hdr_end <= {1'b0, pcm_size_lo});
	wire        hdr_aligned= (hdr_start[8:0] == 9'd0);

	reg [31:0] track_start;
	reg [31:0] track_len;
	reg        blob_checked;
	reg        blob_ok_r;
	assign blob_ok = blob_ok_r;

	// ---- chunk Gray flow --------------------------------------------------
	reg  [CHUNK_W:0] wr_chunk;
	wire [CHUNK_W:0] rd_chunk_sync;

	synch_3 #(.WIDTH(CHUNK_W+1)) rd_chunk_synch (
		.i(rd_chunk_gray), .o(rd_chunk_sync), .clk(clk), .rise(), .fall()
	);

	function automatic [CHUNK_W:0] gray2bin(input [CHUNK_W:0] g);
		integer i;
		begin
			gray2bin[CHUNK_W] = g[CHUNK_W];
			for (i = CHUNK_W-1; i >= 0; i = i - 1)
				gray2bin[i] = gray2bin[i+1] ^ g[i];
		end
	endfunction

	wire [CHUNK_W:0] rd_chunk         = gray2bin(rd_chunk_sync);
	wire [CHUNK_W:0] chunks_in_flight = wr_chunk - rd_chunk;
	wire             ring_has_room    = (chunks_in_flight < NUM_CHUNKS[CHUNK_W:0]);

	always @(posedge clk) wr_chunk_gray <= (wr_chunk >> 1) ^ wr_chunk;

	// ---- sequencer states -------------------------------------------------
	localparam S_IDLE       = 4'd0,
	           S_HDR        = 4'd1,
	           S_HDR_WAIT   = 4'd3,
	           S_READ       = 4'd4,
	           S_READ_WAIT  = 4'd6,
	           S_ADVANCE    = 4'd7,
	           S_DONE       = 4'd8,
	           S_MAGIC      = 4'd10,
	           S_MAGIC_WAIT = 4'd12;

	reg  [3:0] state;
	reg        loop_this_track;
	reg        want_play;          // a track_request is waiting for the magic check
	reg [31:0] cursor;

	// ---- SD request engine (one transfer at a time) -----------------------
	localparam [1:0] SD_IDLE = 2'd0,
	                 SD_REQ  = 2'd1,   // sd_rd high, waiting for sd_ack
	                 SD_DATA = 2'd2;   // sd_ack high, words arriving

	localparam DST_HDR = 1'b0,
	           DST_BUF = 1'b1;

	reg  [1:0] sd_state;
	reg        sd_dst;
	reg        sd_busy;            // transfer in flight
	reg        sd_done_sticky;     // finished (ok or error); cleared by the sequencer
	reg        sd_err;
	reg [TMO_W-1:0] sd_timer;
	reg  [3:0] hdr_cnt;
	reg  [2:0] ack_low;            // ack low for 4 clocks = transfer over and last word landed

	// capture window for header reads
	reg [11:0] cap_w0;
	reg  [3:0] cap_n;
	wire [11:0] cap_rel = sd_buff_addr - cap_w0;
	wire        cap_hit = (sd_buff_addr >= cap_w0) && (cap_rel < {8'd0, cap_n});

	// request launch
	reg        sd_start;
	reg [31:0] start_lba;
	reg  [5:0] start_blk;
	reg        start_dst;
	reg [11:0] start_w0;
	reg  [3:0] start_n;

	// after an abort (track change, stop, mount change) a transfer that Main has already
	// started to serve could still raise sd_ack for a request we no longer want; wait it out
	// (~39 ms at 53.69 MHz, a few poll-loop periods) before issuing the next request, and
	// ignore all data meanwhile.
	reg [SETTLE_W-1:0] settle;
	wire       sd_quiet = (settle == 0) && !sd_ack && !sd_rd;

	// ---- indicator state --------------------------------------------------
	reg  [3:0] ev_pend;           // bit i-1 pending for info code i
	reg [HOLD_W:0] info_hold;
	reg  [2:0] info_pulse;
	reg [15:0] ur_prev;
	wire       primed = (wr_chunk != 0);

	always @(posedge clk) begin
		buf_wr_en <= 0;
		sd_start  <= 0;

		if (reset) begin
			sd_state        <= SD_IDLE;
			sd_busy         <= 0;
			sd_done_sticky  <= 0;
			sd_err          <= 0;
			sd_timer        <= 0;
			sd_rd           <= 0;
			sd_lba          <= 0;
			sd_blk_cnt      <= 0;
			ack_low         <= 0;
			hdr_cnt         <= 0;
			settle          <= {SETTLE_W{1'b1}};
			state           <= S_IDLE;
			wr_chunk        <= 0;
			cursor          <= 0;
			playing         <= 0;
			current_track   <= 0;
			blob_checked    <= 0;
			blob_ok_r       <= 0;
			loop_this_track <= 0;
			want_play       <= 0;
			ev_pend         <= 0;
			info_hold       <= 0;
			info_pulse      <= 0;
			info_req        <= 0;
			info            <= 0;
			ur_prev         <= underruns;
		end
		else begin
			if (settle != 0) settle <= settle - 1'd1;

			//--------------------------------------------------------------
			// SD engine
			//--------------------------------------------------------------
			if (sd_start) begin
				sd_lba         <= start_lba;
				sd_blk_cnt     <= start_blk;
				sd_dst         <= start_dst;
				cap_w0         <= start_w0;
				cap_n          <= start_n;
				hdr_cnt        <= 0;
				sd_busy        <= 1;
				sd_done_sticky <= 0;
				sd_err         <= 0;
				sd_timer       <= 0;
				sd_rd          <= 1;
				sd_state       <= SD_REQ;
			end
			else case (sd_state)
				SD_IDLE: ;

				SD_REQ: begin
					sd_timer <= sd_timer + 1'd1;
					if (sd_ack) begin
						sd_rd    <= 0;          // request taken
						sd_timer <= 0;
						ack_low  <= 0;
						sd_state <= SD_DATA;
					end
					else if (&sd_timer) begin
						sd_rd          <= 0;
						sd_err         <= 1;
						sd_busy        <= 0;
						sd_done_sticky <= 1;
						sd_state       <= SD_IDLE;
						settle         <= {SETTLE_W{1'b1}};  // Main may still answer late
					end
				end

				SD_DATA: begin
					sd_timer <= sd_timer + 1'd1;
					if (sd_buff_wr) begin
						if (sd_dst == DST_BUF) begin
							buf_wr_en   <= 1;
							buf_wr_addr <= {wr_chunk[CHUNK_W-1:0], sd_buff_addr[10:0]};
							buf_wr_data <= sd_buff_dout;
						end
						else if (cap_hit) begin
							hdr[cap_rel[3:0]] <= sd_buff_dout;
							hdr_cnt <= hdr_cnt + 1'd1;
						end
					end
					ack_low <= sd_ack ? 3'd0 : ack_low + 1'd1;
					if (ack_low == 3'd4) begin          // Main finished the transfer
						ack_low        <= 0;
						sd_busy        <= 0;
						sd_done_sticky <= 1;
						sd_state       <= SD_IDLE;
					end
					else if (&sd_timer) begin
						sd_err         <= 1;
						sd_busy        <= 0;
						sd_done_sticky <= 1;
						sd_state       <= SD_IDLE;
						settle         <= {SETTLE_W{1'b1}};
					end
				end

				default: sd_state <= SD_IDLE;
			endcase

			//--------------------------------------------------------------
			// Command / mount sequencer (nothing here ever waits for the 68k side)
			//--------------------------------------------------------------
			// abort any transfer in progress (request withdrawn; late data ignored)
			if (stop_request || track_request || pcm_mount_ev) begin
				if (sd_state != SD_IDLE || sd_rd) begin
					sd_rd          <= 0;
					sd_busy        <= 0;
					sd_state       <= SD_IDLE;
					settle         <= {SETTLE_W{1'b1}};
				end
				sd_done_sticky <= 0;
			end

			if (pcm_mount_ev) begin
				blob_checked <= 0;
				blob_ok_r    <= 0;
				playing      <= 0;
				state        <= S_IDLE;
				if (!pcm_present) ev_pend[2] <= 1;      // code 3: ejected
			end
			else if (stop_request) begin
				state     <= S_IDLE;
				playing   <= 0;
				want_play <= 0;
			end

			if (track_request && !pcm_mount_ev) begin
				current_track   <= track_num;
				loop_this_track <= track_loop;
				wr_chunk        <= 0;
				if (blob_ok_r) begin
					state     <= S_HDR;
					want_play <= 0;
				end
				else if (!blob_checked) begin
					want_play <= 1;
					state     <= S_IDLE;     // the idle check below runs the magic read
				end
				else begin
					playing   <= 0;
					state     <= S_IDLE;
					want_play <= 0;
				end
			end
			else if (!stop_request && !pcm_mount_ev) begin
				case (state)
				S_IDLE: begin
					// header check right after (re)mount / after leaving reset
					if (!blob_checked) begin
						if (!pcm_present) begin
							blob_checked <= 1;
							blob_ok_r    <= 0;
						end
						else if (sd_quiet && !sd_busy && !sd_done_sticky) begin
							start_lba <= 32'd0;
							start_blk <= 6'd0;     // 1 sector
							start_dst <= DST_HDR;
							start_w0  <= 12'd0;
							start_n   <= 4'd12;
							sd_start  <= 1;
							state     <= S_MAGIC_WAIT;
						end
					end
				end

				S_MAGIC_WAIT: if (sd_done_sticky) begin
					sd_done_sticky <= 0;
					blob_checked   <= 1;
					if (sd_err || !blob_valid || (hdr_cnt < 4'd12)) begin
						blob_ok_r <= 0;
						playing   <= 0;
						want_play <= 0;
						state     <= S_IDLE;
						ev_pend[1] <= 1;               // code 2: invalid
					end
					else begin
						blob_ok_r <= 1;
						ev_pend[0] <= 1;               // code 1: ok
						state     <= want_play ? S_HDR : S_IDLE;
						want_play <= 0;
					end
				end

				S_HDR: if (sd_quiet && !sd_busy && !sd_done_sticky) begin
					// entry at 0x18 + 16*track; 2 sectors cover a straddling entry
					start_lba <= {9'd0, ({20'd0, current_track, 4'd0} + 32'h18) >> 9};
					start_blk <= 6'd1;
					start_dst <= DST_HDR;
					start_w0  <= ({20'd0, current_track, 4'd0} + 32'h18) >> 1 & 12'h0FF;
					start_n   <= 4'd8;
					sd_start  <= 1;
					state     <= S_HDR_WAIT;
				end

				S_HDR_WAIT: if (sd_done_sticky) begin
					sd_done_sticky <= 0;
					if (sd_err || hdr_cnt < 4'd8 || hdr_len == 0 || hdr_smpls == 0 || hdr_off_hi != 0
					    || !hdr_inside || !hdr_aligned) begin
						playing <= 0;
						state   <= S_IDLE;
					end
					else begin
						track_start <= hdr_start;
						track_len   <= hdr_len;
						cursor      <= hdr_start;
						playing     <= 1;
						state       <= S_READ;
					end
				end

				S_READ: if (ring_has_room && sd_quiet && !sd_busy && !sd_done_sticky) begin
					start_lba <= {9'd0, cursor[31:9]};
					start_blk <= (CHUNK_BYTES / 512) - 1;     // 4 KiB = 8 sectors
					start_dst <= DST_BUF;
					start_w0  <= 12'd0;
					start_n   <= 4'd0;
					sd_start  <= 1;
					state     <= S_READ_WAIT;
				end

				S_READ_WAIT: if (sd_done_sticky) begin
					sd_done_sticky <= 0;
					if (sd_err) state <= S_DONE;
					else        state <= S_ADVANCE;
				end

				S_ADVANCE: begin
					wr_chunk <= wr_chunk + 1'd1;
					cursor   <= cursor + CHUNK_BYTES[31:0];
					if ((cursor + CHUNK_BYTES[31:0]) >= (track_start + track_len))
						state <= S_DONE;
					else
						state <= S_READ;
				end

				S_DONE: begin
					if (loop_this_track) begin
						cursor <= track_start;
						state  <= S_READ;
					end
					else begin
						playing <= 0;
						state   <= S_IDLE;
					end
				end

				default: state <= S_IDLE;
				endcase
			end

			//--------------------------------------------------------------
			// Indicator: info codes 1..4 (one OSD message per event, rate limited)
			//--------------------------------------------------------------
			ur_prev <= underruns;
			if (underruns != ur_prev && playing && primed) ev_pend[3] <= 1;   // code 4

			if (info_pulse != 0) begin
				info_pulse <= info_pulse - 1'd1;
				if (info_pulse == 3'd1) info_req <= 0;
			end
			if (info_hold != 0) info_hold <= info_hold - 1'd1;
			else if (info_pulse == 0 && ev_pend != 0 && !info_req) begin
				info_req   <= 1;
				info_pulse <= 3'd5;
				if      (ev_pend[1]) begin info <= 8'd2; ev_pend[1] <= 0; info_hold <= {HOLD_W{1'b1}}; end
				else if (ev_pend[2]) begin info <= 8'd3; ev_pend[2] <= 0; info_hold <= {HOLD_W{1'b1}}; end
				else if (ev_pend[0]) begin info <= 8'd1; ev_pend[0] <= 0; info_hold <= {HOLD_W{1'b1}}; end
				else                 begin info <= 8'd4; ev_pend[3] <= 0; info_hold <= {(HOLD_W+1){1'b1}}; end
			end
		end
	end

endmodule
