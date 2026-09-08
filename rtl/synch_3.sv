// 3-stage synchronizer (from Analogue Pocket apf/common.v).
// Needed by paprium_cdda_buf / paprium_cdda_fetch chunk Gray CDC.
// When both sides share clk_sys the extra latency is harmless.

module synch_3 #(parameter WIDTH = 1) (
	input  wire [WIDTH-1:0] i,
	output reg  [WIDTH-1:0] o,
	input  wire             clk,
	output wire             rise,
	output wire             fall
);

reg [WIDTH-1:0] stage_1;
reg [WIDTH-1:0] stage_2;
reg [WIDTH-1:0] stage_3;

assign rise = (WIDTH == 1) ? (o & ~stage_3) : 1'b0;
assign fall = (WIDTH == 1) ? (~o & stage_3) : 1'b0;

always @(posedge clk)
	{stage_3, o, stage_2, stage_1} <= {o, stage_2, stage_1, i};

endmodule
