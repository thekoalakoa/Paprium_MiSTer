// ---------------------------------------------------------------------------
// One-shot paprium.pcm → DDRAM loader (ioctl FS3 path).
//
// hps_io ioctl_addr is 27 bits → practical cap ~128 MiB. Full shipping PPAD
// (~543 MB) MUST be filled by HPS mmap into BLOB_BASE_BYTE=0x10000000
// (scripts/paprium_pcm_preload + mem=256M). Do not shrink the asset. This
// module still serves:
//   - small / truncated test blobs
//   - future hps_io addr widen
//   - documenting the FPGA write contract
//
// Missing file → no writes → fetch magic fails → blob_ok=0 → silent BGM.
// ---------------------------------------------------------------------------

module paprium_pcm_load #(
	parameter [31:0] BLOB_BASE_BYTE = 32'h1000_0000
) (
	input             clk,
	input             reset,

	input             download,       // ioctl_download && index==PCM
	input             ioctl_wr,
	input      [26:0] ioctl_addr,     // byte address (WIDE: steps by 2)
	input      [15:0] ioctl_data,
	output reg        ioctl_wait,

	// DDRAM write master (muxed ahead of fetch when active)
	output            DDRAM_CLK,
	input             DDRAM_BUSY,
	output reg  [7:0] DDRAM_BURSTCNT,
	output reg [28:0] DDRAM_ADDR,
	input      [63:0] DDRAM_DOUT,     // unused
	input             DDRAM_DOUT_READY,
	output            DDRAM_RD,
	output reg [63:0] DDRAM_DIN,
	output reg  [7:0] DDRAM_BE,
	output reg        DDRAM_WE,

	output reg        loading,
	output reg [31:0] bytes_written
);

	assign DDRAM_CLK = clk;
	assign DDRAM_RD  = 1'b0;

	localparam [28:0] BLOB_BASE_DDR = BLOB_BASE_BYTE[31:3];

	reg [15:0] word0, word1, word2;
	reg  [1:0] fill;
	reg        have_quad;
	reg [63:0] quad;
	reg [28:0] wr_addr;
	reg        pending;

	localparam [1:0] ST_IDLE = 2'd0,
	                 ST_REQ  = 2'd1,
	                 ST_WAIT = 2'd2;

	reg [1:0] state;

	always @(posedge clk) begin
		DDRAM_WE <= 0;
		ioctl_wait <= pending || (state != ST_IDLE);

		if (reset) begin
			fill          <= 0;
			have_quad     <= 0;
			pending       <= 0;
			state         <= ST_IDLE;
			loading       <= 0;
			bytes_written <= 0;
		end
		else if (!download) begin
			fill      <= 0;
			have_quad <= 0;
			pending   <= 0;
			state     <= ST_IDLE;
			loading   <= 0;
		end
		else begin
			loading <= 1;

			if (ioctl_wr && !pending) begin
				case (fill)
					2'd0: begin word0 <= ioctl_data; fill <= 2'd1; end
					2'd1: begin word1 <= ioctl_data; fill <= 2'd2; end
					2'd2: begin word2 <= ioctl_data; fill <= 2'd3; end
					2'd3: begin
						quad <= {ioctl_data, word2, word1, word0};
						wr_addr <= BLOB_BASE_DDR + ioctl_addr[26:3]; // aligned to this 8-byte group
						have_quad <= 1;
						pending <= 1;
						fill <= 2'd0;
					end
				endcase
			end

			case (state)
				ST_IDLE: if (have_quad) begin
					have_quad <= 0;
					state <= ST_REQ;
				end
				ST_REQ: if (!DDRAM_BUSY) begin
					DDRAM_ADDR     <= wr_addr;
					DDRAM_BURSTCNT <= 8'd1;
					DDRAM_DIN      <= quad;
					DDRAM_BE       <= 8'hFF;
					DDRAM_WE       <= 1;
					state          <= ST_WAIT;
				end
				ST_WAIT: begin
					// write posted; no DOUT_READY for writes on this bridge — complete next cycle
					bytes_written <= bytes_written + 32'd8;
					pending <= 0;
					state   <= ST_IDLE;
				end
				default: state <= ST_IDLE;
			endcase
		end
	end

endmodule
