// ---------------------------------------------------------------------------
// Paprium CDDA fetch — MiSTer DDRAM producer (Option D / POCKET_CDDA_MISTER).
//
// Pocket 0.2.1 used an APF dataslot (id 300) + BRIDGE data_loader to random-
// access paprium.pcm (PPAD IMA). MiSTer has no APF; the whole blob is one-shot
// loaded into DDR (HPS mmap preferred; ioctl FS3 for ≤128 MiB test blobs) at
// BLOB_BASE_BYTE. This module is a DDRAM read master that keeps the Pocket
// magic / header / chunk state-machine semantics.
//
// Clock: clk_sys (same domain as paprium_cdda_buf / play and the DDRAM port).
//
// SD path: games/MegaDrive/Paprium/paprium.pcm
// Missing / invalid blob → blob_ok=0 → silent BGM (game + SFX still run).
// ---------------------------------------------------------------------------

module paprium_cdda_fetch #(
	// Byte address in the FPGA DDRAM map. 64 MiB — leaves the legacy MD+
	// 64 KB ring at 0x30000000 clear for non-Paprium MD+ games.
	// ~543 MB PPAD ends near 0x25F00000 (< 1 GiB).
	parameter [31:0] BLOB_BASE_BYTE = 32'h0400_0000,
	parameter        CHUNK_BYTES    = 4096,
	parameter        NUM_CHUNKS     = 4,
	parameter        CHUNK_W        = $clog2(NUM_CHUNKS),
	parameter        DIAG_MODE      = 1'b0
) (
	input  wire        clk,
	input  wire        reset,

	input  wire        track_request,   // one-cycle pulse (clk_sys)
	input  wire  [7:0] track_num,
	input  wire        track_loop,
	input  wire        stop_request,

	output            DDRAM_CLK,
	input             DDRAM_BUSY,
	output reg  [7:0] DDRAM_BURSTCNT,
	output reg [28:0] DDRAM_ADDR,
	input      [63:0] DDRAM_DOUT,
	input             DDRAM_DOUT_READY,
	output reg        DDRAM_RD,
	output     [63:0] DDRAM_DIN,
	output      [7:0] DDRAM_BE,
	output            DDRAM_WE,

	// Direct write into paprium_cdda_buf (replaces APF data_loader)
	output reg        buf_wr_en,
	output reg [12:0] buf_wr_addr,   // 16-bit word index within 16 KB ring
	output reg [15:0] buf_wr_data,

	input  wire [CHUNK_W:0] rd_chunk_gray,
	output reg  [CHUNK_W:0] wr_chunk_gray,

	output reg         playing,
	output reg   [7:0] current_track,
	output wire        blob_ok
);

	assign DDRAM_CLK = clk;
	assign DDRAM_DIN = 64'd0;
	assign DDRAM_BE  = 8'hFF;
	assign DDRAM_WE  = 1'b0;

	localparam [28:0] BLOB_BASE_DDR = BLOB_BASE_BYTE[31:3];

	wire [7:0] req_track = track_num;
	localparam [7:0] DIAG_SRC = 8'd5;
	wire [7:0] hdr_track = DIAG_MODE ? DIAG_SRC : current_track;

	localparam [15:0] DIAG_CPS = 16'd47;
	wire [3:0] diag_tens = (current_track >= 8'd60) ? 4'd6 :
	                       (current_track >= 8'd50) ? 4'd5 :
	                       (current_track >= 8'd40) ? 4'd4 :
	                       (current_track >= 8'd30) ? 4'd3 :
	                       (current_track >= 8'd20) ? 4'd2 :
	                       (current_track >= 8'd10) ? 4'd1 : 4'd0;
	wire [7:0] diag_ones = current_track - (diag_tens * 8'd10);
	reg  [1:0] diag_phase;
	reg [15:0] diag_chunks;
	reg [26:0] diag_gap;
	wire [15:0] diag_target = (diag_phase == 2'd0) ? ({12'd0, diag_tens} * DIAG_CPS)
	                                              : ({8'd0,  diag_ones} * DIAG_CPS);

	// ---- header capture ---------------------------------------------------
	reg [15:0] hdr [0:11];
	reg  [3:0] hdr_count;

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

	// ---- high-level sequencer states (Pocket names) -----------------------
	localparam S_IDLE       = 4'd0,
	           S_HDR        = 4'd1,
	           S_HDR_WAIT   = 4'd3,
	           S_READ       = 4'd4,
	           S_READ_WAIT  = 4'd6,
	           S_ADVANCE    = 4'd7,
	           S_DONE       = 4'd8,
	           S_DIAG_GAP   = 4'd9,
	           S_MAGIC      = 4'd10,
	           S_MAGIC_WAIT = 4'd12;

	reg  [3:0] state;
	reg        loop_this_track;
	reg [31:0] cursor;

	// ---- DDR beat engine + buf spill (single always) ----------------------
	localparam [2:0] DDR_IDLE = 3'd0,
	                 DDR_REQ  = 3'd1,
	                 DDR_WAIT = 3'd2,
	                 DDR_SPILL= 3'd3;

	localparam [1:0] DST_HDR = 2'd0,
	                 DST_BUF = 2'd1;

	reg  [2:0] ddr_state;
	reg  [1:0] ddr_dst;
	reg [28:0] ddr_word_addr;
	reg [15:0] ddr_words_left;
	reg        ddr_busy;          // op in flight
	reg        ddr_done_sticky;   // set when op finishes; cleared by sequencer
	reg        ddr_err;
	reg [21:0] ddr_timer;
	reg [12:0] buf_word;          // next ring word index
	reg [63:0] beat_latch;
	reg  [1:0] spill_idx;         // 0..3 halfwords

	// Start a DDR read: called by setting these then ddr_start<=1 for one cycle
	reg        ddr_start;
	reg [31:0] start_byte_off;
	reg [15:0] start_byte_len;    // multiple of 8
	reg  [1:0] start_dst;
	reg [12:0] start_buf_word;

	always @(posedge clk) begin
		DDRAM_RD  <= 0;
		buf_wr_en <= 0;
		ddr_start <= 0; // default; sequencer may override in same block below

		if (reset) begin
			ddr_state       <= DDR_IDLE;
			ddr_busy        <= 0;
			ddr_done_sticky <= 0;
			ddr_err         <= 0;
			ddr_timer       <= 0;
			hdr_count       <= 0;
			spill_idx       <= 0;
			state           <= S_IDLE;
			wr_chunk        <= 0;
			cursor          <= 0;
			playing         <= 0;
			current_track   <= 0;
			diag_phase      <= 0;
			diag_chunks     <= 0;
			diag_gap        <= 0;
			blob_checked    <= 0;
			blob_ok_r       <= 0;
			loop_this_track <= 0;
		end
		else begin
			//--------------------------------------------------------------
			// DDR / spill engine
			//--------------------------------------------------------------
			if (ddr_start) begin
				ddr_word_addr   <= BLOB_BASE_DDR + start_byte_off[31:3];
				ddr_words_left  <= {3'd0, start_byte_len[15:3]};
				ddr_dst         <= start_dst;
				buf_word        <= start_buf_word;
				hdr_count       <= 0;
				ddr_busy        <= 1;
				ddr_done_sticky <= 0;
				ddr_err         <= 0;
				ddr_timer       <= 0;
				ddr_state       <= DDR_REQ;
			end
			else case (ddr_state)
				DDR_IDLE: ;

				DDR_REQ: begin
					ddr_timer <= ddr_timer + 1'd1;
					if (!DDRAM_BUSY) begin
						DDRAM_ADDR     <= ddr_word_addr;
						DDRAM_BURSTCNT <= 8'd1;
						DDRAM_RD       <= 1;
						ddr_state      <= DDR_WAIT;
						ddr_timer      <= 0;
					end
					else if (&ddr_timer) begin
						ddr_err         <= 1;
						ddr_busy        <= 0;
						ddr_done_sticky <= 1;
						ddr_state       <= DDR_IDLE;
					end
				end

				DDR_WAIT: begin
					ddr_timer <= ddr_timer + 1'd1;
					if (DDRAM_DOUT_READY) begin
						ddr_timer <= 0;
						if (ddr_dst == DST_HDR) begin
							hdr[hdr_count + 0] <= DDRAM_DOUT[15:0];
							hdr[hdr_count + 1] <= DDRAM_DOUT[31:16];
							hdr[hdr_count + 2] <= DDRAM_DOUT[47:32];
							hdr[hdr_count + 3] <= DDRAM_DOUT[63:48];
							hdr_count <= hdr_count + 4'd4;

							ddr_word_addr  <= ddr_word_addr + 1'd1;
							ddr_words_left <= ddr_words_left - 1'd1;
							if (ddr_words_left <= 16'd1) begin
								ddr_busy        <= 0;
								ddr_done_sticky <= 1;
								ddr_state       <= DDR_IDLE;
							end
							else
								ddr_state <= DDR_REQ;
						end
						else begin
							beat_latch <= DDRAM_DOUT;
							spill_idx  <= 0;
							ddr_state  <= DDR_SPILL;
						end
					end
					else if (&ddr_timer) begin
						ddr_err         <= 1;
						ddr_busy        <= 0;
						ddr_done_sticky <= 1;
						ddr_state       <= DDR_IDLE;
					end
				end

				DDR_SPILL: begin
					buf_wr_en   <= 1;
					buf_wr_addr <= buf_word;
					case (spill_idx)
						2'd0: buf_wr_data <= beat_latch[15:0];
						2'd1: buf_wr_data <= beat_latch[31:16];
						2'd2: buf_wr_data <= beat_latch[47:32];
						2'd3: buf_wr_data <= beat_latch[63:48];
					endcase
					buf_word  <= buf_word + 1'd1;
					spill_idx <= spill_idx + 1'd1;

					if (spill_idx == 2'd3) begin
						ddr_word_addr  <= ddr_word_addr + 1'd1;
						ddr_words_left <= ddr_words_left - 1'd1;
						if (ddr_words_left <= 16'd1) begin
							ddr_busy        <= 0;
							ddr_done_sticky <= 1;
							ddr_state       <= DDR_IDLE;
						end
						else
							ddr_state <= DDR_REQ;
					end
				end

				default: ddr_state <= DDR_IDLE;
			endcase

			//--------------------------------------------------------------
			// Command / Pocket sequencer
			//--------------------------------------------------------------
			if (stop_request && !(DIAG_MODE && (state != S_IDLE))) begin
				state    <= S_IDLE;
				playing  <= 0;
				ddr_busy <= 0; // abandon in-flight visually; HW may still finish beat
				ddr_state <= DDR_IDLE;
				ddr_done_sticky <= 0;
			end

			if (track_request) begin
				current_track   <= req_track;
				loop_this_track <= track_loop;
				wr_chunk        <= 0;
				diag_phase      <= 0;
				diag_chunks     <= 0;
				diag_gap        <= 0;
				ddr_done_sticky <= 0;
				ddr_busy        <= 0;
				ddr_state       <= DDR_IDLE;
				if (DIAG_MODE) playing <= 1;
				if (!blob_checked)
					state <= S_MAGIC;
				else if (blob_ok_r)
					state <= S_HDR;
				else begin
					playing <= 0;
					state   <= S_IDLE;
				end
			end
			else begin
				case (state)
				S_IDLE: ;

				S_MAGIC: if (!ddr_busy && !ddr_done_sticky) begin
					start_byte_off <= 32'd0;
					start_byte_len <= 16'd24;
					start_dst      <= DST_HDR;
					start_buf_word <= 13'd0;
					ddr_start      <= 1;
					state          <= S_MAGIC_WAIT;
				end

				// ddr_done_sticky is set the cycle AFTER the last hdr write's NBA
				// lands for the next cycle — wait one extra for hdr_count/blob_valid.
				S_MAGIC_WAIT: if (ddr_done_sticky) begin
					ddr_done_sticky <= 0;
					blob_checked    <= 1;
					if (ddr_err || !blob_valid || (hdr_count < 4'd12)) begin
						blob_ok_r <= 0;
						playing   <= 0;
						state     <= S_IDLE;
					end
					else begin
						blob_ok_r <= 1;
						state     <= S_HDR;
					end
				end

				S_HDR: if (!ddr_busy && !ddr_done_sticky) begin
					start_byte_off <= 32'h18 + {20'd0, hdr_track, 4'd0};
					start_byte_len <= 16'd16;
					start_dst      <= DST_HDR;
					start_buf_word <= 13'd0;
					ddr_start      <= 1;
					state          <= S_HDR_WAIT;
				end

				S_HDR_WAIT: if (ddr_done_sticky) begin
					ddr_done_sticky <= 0;
					if (ddr_err || hdr_len == 0 || hdr_smpls == 0 || hdr_off_hi != 0) begin
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

				S_READ: if (ring_has_room && !ddr_busy && !ddr_done_sticky) begin
					start_byte_off <= cursor;
					start_byte_len <= CHUNK_BYTES[15:0];
					start_dst      <= DST_BUF;
					// wr_chunk[low] * (CHUNK_BYTES/2) = chunk * 2048
					start_buf_word <= {wr_chunk[CHUNK_W-1:0], 11'b0};
					ddr_start      <= 1;
					state          <= S_READ_WAIT;
				end

				S_READ_WAIT: if (ddr_done_sticky) begin
					ddr_done_sticky <= 0;
					if (ddr_err) state <= S_DONE;
					else         state <= S_ADVANCE;
				end

				S_ADVANCE: begin
					wr_chunk <= wr_chunk + 1'd1;
					if (DIAG_MODE) begin
						diag_chunks <= diag_chunks + 1'd1;
						if ((cursor + CHUNK_BYTES[31:0]) >= (track_start + track_len))
							cursor <= track_start;
						else
							cursor <= cursor + CHUNK_BYTES[31:0];
						if ((diag_chunks + 1'd1) >= diag_target) begin
							if (diag_phase == 2'd0) state <= S_DIAG_GAP;
							else                   state <= S_DONE;
						end
						else state <= S_READ;
					end
					else begin
						cursor <= cursor + CHUNK_BYTES[31:0];
						if ((cursor + CHUNK_BYTES[31:0]) >= (track_start + track_len))
							state <= S_DONE;
						else
							state <= S_READ;
					end
				end

				S_DIAG_GAP: begin
					diag_gap <= diag_gap + 1'd1;
					if (&diag_gap) begin
						diag_gap    <= 0;
						diag_phase  <= 2'd2;
						diag_chunks <= 0;
						state       <= S_READ;
					end
				end

				S_DONE: begin
					if (loop_this_track && !DIAG_MODE) begin
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
		end
	end

endmodule
