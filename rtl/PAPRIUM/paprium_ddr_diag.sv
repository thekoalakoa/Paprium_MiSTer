// ---------------------------------------------------------------------------
// Paprium DDR3 diagnostic writer
// ---------------------------------------------------------------------------
// Streams 16 x 32-bit core-state words into DDR3 so the ARM/Linux side can read
// the LIVE game state over SSH with `devmem`, completely outside the video path.
//
// (Background: the old on-screen debug overlay's only timing-violating path was
//  its digit-render -> gamma, which corrupted the NUMBERS it displayed even with
//  the OSD off. The underlying clk_sys counters were always correct; this writer
//  ships those same correct counters out through an untouched, idle channel.)
//
// For Paprium the core runs `use_sdr = 1`, so the whole DDR3 ("ddram") interface
// is otherwise unused (the 8 MB flash lives in SDRAM). We borrow it.
//
// Physical layout, DDR3 base 0x30000000 (= ddram ROM region, idle for Paprium).
// 8 x 64-bit beats carry 16 x 32-bit values; read with `devmem <addr> 32`:
//   0x30000000  v0  round counter   (increments per write round -> "channel alive")
//   0x30000004  v1  magic 0x50415052 = "PAPR" (channel + base address verified)
//   0x30000008  v2 ...               (v2..v15 supplied by the caller via `words`)
//   0x3000000C  v3
//   ...         ...
//   0x3000003C  v15
//
// CDC note: `words` originates in clk_sys; this runs in clk_ram (= 2x clk_sys,
// same PLL, synchronous). With timing met the sample is deterministic, and the
// game is stalled so the values are near-static anyway. A coherent snapshot is
// latched at the start of each round so all 8 beats are from one instant.
// ---------------------------------------------------------------------------

module paprium_ddr_diag
(
	input             clk,          // clk_ram (DDRAM clock domain)
	input             enable,       // run only for the Paprium cart

	input             DDRAM_BUSY,
	output reg  [7:0] DDRAM_BURSTCNT,
	output reg [28:0] DDRAM_ADDR,
	output reg        DDRAM_RD,
	output reg [63:0] DDRAM_DIN,
	output reg  [7:0] DDRAM_BE,
	output reg        DDRAM_WE,

	input     [447:0] words         // v2..v15 (14 x 32-bit), v2 in [31:0]
);

	// 0x30000000 as a 64-bit-word address (byte >> 3).
	localparam [28:0] DDR_BASE = 29'h0600_0000;
	localparam [31:0] DIAG_MAGIC = 32'h5041_5052; // "PAPR"

	reg  [2:0]  idx       = 3'd0;   // which 64-bit beat, 0..7
	reg  [31:0] round_ctr = 32'd0;
	reg [447:0] snap      = 448'd0; // coherent v2..v15 snapshot for the round

	always @(posedge clk) begin
		DDRAM_RD       <= 1'b0;
		DDRAM_BURSTCNT <= 8'd1;
		DDRAM_BE       <= 8'hFF;

		if (!enable) begin
			DDRAM_WE  <= 1'b0;
			idx       <= 3'd0;
			round_ctr <= 32'd0;
		end
		else if (!DDRAM_BUSY) begin
			if (DDRAM_WE) begin
				// Write accepted this cycle; advance to the next beat.
				DDRAM_WE <= 1'b0;
				if (idx == 3'd7) begin
					idx       <= 3'd0;
					round_ctr <= round_ctr + 32'd1;
				end
				else begin
					idx <= idx + 3'd1;
				end
			end
			else begin
				// Latch a coherent snapshot of v2..v15 at the start of a round.
				if (idx == 3'd0) snap <= words;
				DDRAM_WE   <= 1'b1;
				DDRAM_ADDR <= DDR_BASE + {26'd0, idx};
				// Beat 0 carries v1/v0; beats 1..7 carry v(2i)/v(2i+1) from the
				// snapshot. Beat i (i>=1) -> words index 2*(i-1) and 2*(i-1)+1,
				// i.e. snap bits [ (i-1)*64 +: 64 ].
				DDRAM_DIN  <= (idx == 3'd0) ? {DIAG_MAGIC, round_ctr}
				                            : snap_beat(idx);
			end
		end
	end

	// Beats 1..7 map to snap[(idx-1)*64 +: 64].
	function [63:0] snap_beat(input [2:0] i);
		reg [8:0] base;
		begin
			base = (i - 3'd1) * 9'd64;
			snap_beat = snap[base +: 64];
		end
	endfunction

endmodule
