//
// audio_cond.sv
//
// Copyright (c) 2023 Alexey Melnikov
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module audio_cond
(
	input         clk,
	input         reset,
	input         mute,

	input   [1:0] lpf_mode,
	input         fm_mode,

	input         fm_clk1,
	input         fm_sel23,
	input   [8:0] MOL,
	input   [8:0] MOR,
	input   [9:0] MOL_2612,
	input   [9:0] MOR_2612,
	input  [15:0] PSG,
	input  [13:0] sms_fm_audio,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R
);

reg  [15:0] md_fm_l, md_fm_r;
always @(posedge clk) begin
	reg [13:0] out_l, out_r;
	reg [13:0] MOL3_s,MOR3_s,MOL2_s,MOR2_s;
	reg [13:0] fm_l,fm_r;
	reg        clk_d1, clk_d2, clk_d3, sel23_d1, sel23_d2;
	
	MOL3_s <= {{6{~MOL[8]}},MOL[7:0]};
	MOR3_s <= {{6{~MOR[8]}},MOR[7:0]};
	MOL2_s <= {{5{MOL_2612[9]}},MOL_2612[8:0]} + {{5{MOL_2612[9]}},MOL_2612[8:0]} + {{5{MOL_2612[9]}},MOL_2612[8:0]};
	MOR2_s <= {{5{MOR_2612[9]}},MOR_2612[8:0]} + {{5{MOR_2612[9]}},MOR_2612[8:0]} + {{5{MOR_2612[9]}},MOR_2612[8:0]};
	fm_l   <= fm_mode ? MOL3_s : MOL2_s;
	fm_r   <= fm_mode ? MOR3_s : MOR2_s;

	clk_d1 <= fm_clk1;
	clk_d2 <= clk_d1;

	sel23_d1 <= fm_sel23;
	sel23_d2 <= sel23_d1;

	clk_d3 <= clk_d2;
	if(clk_d3 & ~clk_d2) begin
		out_l <= out_l + fm_l;
		out_r <= out_r + fm_r;
		if(sel23_d2) begin
			md_fm_l <= {out_l + fm_l,2'b00};
			md_fm_r <= {out_r + fm_r,2'b00};
			out_l <= 0;
			out_r <= 0;
		end
	end
end

wire [15:0] md_fm_lpf_l;
wire [15:0] md_fm_lpf_r;

genesis_fm_lpf fm_lpf_l
(
	.clk(clk),
	.reset(reset),

	.in(md_fm_l),
	.out(md_fm_lpf_l)
);

genesis_fm_lpf fm_lpf_r
(
	.clk(clk),
	.reset(reset),

	.in(md_fm_r),
	.out(md_fm_lpf_r)
);

wire ce_flt;
CEGen fltce
(
	.CLK(clk),
	.RST_N(~reset),

	.IN_CLK(53693175),
	.OUT_CLK(7056000),

	.CE(ce_flt)
);

wire [15:0] psg_amp = PSG + PSG[15:1];

// 8KHz 2tap
IIR_filter_psga
#(
	.use_params(1),
	.stereo(0),
	.coeff_x (0.0000943),
	.coeff_x0(2),
	.coeff_x1(1),
	.coeff_x2(0),
	.coeff_y0(-1.98992552008492529225),
	.coeff_y1( 0.98997601394542067421),
	.coeff_y2(0) 
)
psg_iir
(
	.clk(clk),
	.reset(reset),

	.ce(ce_flt),
	.sample_ce(1),

	.input_l(psg_amp),
	.output_l(psg)
);

wire [15:0] psg;

reg [15:0] pre_lpf_l,pre_lpf_r;
always @(posedge clk) begin
	reg [15:0] sms_fm;
	reg [15:0] al,ar;

	sms_fm <= ^sms_fm_audio[13:12] ? {{2{sms_fm_audio[13]}}, {12{sms_fm_audio[12]}}, 2'b00} : {sms_fm_audio[12],sms_fm_audio[12:0], 2'b00};

	al <= ((lpf_mode == 1) ? md_fm_lpf_l : md_fm_l) + sms_fm + ((lpf_mode == 3) ? psg_amp : psg);
	ar <= ((lpf_mode == 1) ? md_fm_lpf_r : md_fm_r) + sms_fm + ((lpf_mode == 3) ? psg_amp : psg);

	pre_lpf_l <= ^al[15:14] ? {al[15],{15{al[14]}}} : {al[14:0], 1'b0};
	pre_lpf_r <= ^ar[15:14] ? {ar[15],{15{ar[14]}}} : {ar[14:0], 1'b0};
end

wire [15:0] audio_l, audio_r;
genesis_lpf lpf_left
(
	.clk(clk),
	.reset(reset),

	.lpf_mode(lpf_mode),
	.in(pre_lpf_l),
	.out(audio_l)
);

genesis_lpf lpf_right
(
	.clk(clk),
	.reset(reset),

	.lpf_mode(lpf_mode),
	.in(pre_lpf_r),
	.out(audio_r)
);

assign AUDIO_L = mute ? 16'd0 : audio_l;
assign AUDIO_R = mute ? 16'd0 : audio_r;

endmodule

// FXPSGA: private copy of sys/iir_filter.v IIR_filter, used ONLY by psg_iir above.
// Only change vs the shared module: the free-running register on x (see the x_pre/x lines).
// iir_filter_tap is the unchanged shared module from sys/iir_filter.v.
module IIR_filter_psga
#(
	parameter use_params = 1,                     // set to 1 to use following parameters, 0 for input port variables.
	parameter stereo   =  1,                      // 0 for mono (input_l)

	parameter coeff_x  =  0.00000774701983513660, // Base gain value for X. Float. Range: 0.0 ... 0.999(9)
	parameter coeff_x0 =  3,                      // Gain scale factor for X0. Integer. Range -7 ... +7
	parameter coeff_x1 =  3,                      // Gain scale factor for X1. Integer. Range -7 ... +7
	parameter coeff_x2 =  1,                      // Gain scale factor for X2. Integer. Range -7 ... +7
	parameter coeff_y0 = -2.96438150626551080000, // Coefficient for Y0. Float. Range -3.999(9) ... 3.999(9)
	parameter coeff_y1 =  2.92939452735121100000, // Coefficient for Y1. Float. Range -3.999(9) ... 3.999(9)
	parameter coeff_y2 = -0.96500747158831091000  // Coefficient for Y2. Float. Range -3.999(9) ... 3.999(9)
)
(
	input         clk,
	input         reset,

	input         ce,        // must be double of calculated rate for stereo!
	input         sample_ce, // desired output sample rate

	input  [39:0] cx,
	input   [7:0] cx0,
	input   [7:0] cx1,
	input   [7:0] cx2,
	input  [23:0] cy0,
	input  [23:0] cy1,
	input  [23:0] cy2,

	input  [15:0] input_l,  input_r,  // signed samples
	output [15:0] output_l, output_r  // signed samples
);

localparam  [39:0] pcoeff_x  = coeff_x  * 40'h8000000000;
localparam  [31:0] pcoeff_y0 = coeff_y0 * 24'h200000;
localparam  [31:0] pcoeff_y1 = coeff_y1 * 24'h200000;
localparam  [31:0] pcoeff_y2 = coeff_y2 * 24'h200000;

wire [39:0] vcoeff    = use_params ? pcoeff_x        : cx;
wire [23:0] vcoeff_y0 = use_params ? pcoeff_y0[23:0] : cy0;
wire [23:0] vcoeff_y1 = use_params ? pcoeff_y1[23:0] : cy1;
wire [23:0] vcoeff_y2 = use_params ? pcoeff_y2[23:0] : cy2;

wire [59:0] inp_mul = $signed(inp) * $signed(vcoeff);

wire [39:0] x_pre = inp_mul[59:20];
reg  [39:0] x;
always @(posedge clk) x <= x_pre; // FXPSGA: free-running register on x (no ce, no reset)
wire [39:0] y = x + tap0;

wire [39:0] tap0;
iir_filter_tap iir_tap_0
(
	.clk(clk),
	.reset(reset),
	.ce(ce),
	.ch(ch),
	.cx(use_params ? coeff_x0[7:0] : cx0),
	.cy(vcoeff_y0),
	.x(x),
	.y(y),
	.z(tap1),
	.tap(tap0)
);

wire [39:0] tap1;
iir_filter_tap iir_tap_1
(
	.clk(clk),
	.reset(reset),
	.ce(ce),
	.ch(ch),
	.cx(use_params ? coeff_x1[7:0] : cx1),
	.cy(vcoeff_y1),
	.x(x),
	.y(y),
	.z(tap2),
	.tap(tap1)
);

wire [39:0] tap2;
iir_filter_tap iir_tap_2
(
	.clk(clk),
	.reset(reset),
	.ce(ce),
	.ch(ch),
	.cx(use_params ? coeff_x2[7:0] : cx2),
	.cy(vcoeff_y2),
	.x(x),
	.y(y),
	.z(0),
	.tap(tap2)
);

wire [15:0] y_clamp = (~y[39] & |y[38:35]) ? 16'h7FFF : (y[39] & ~&y[38:35]) ? 16'h8000 : y[35:20];

reg        ch = 0;
reg [15:0] out_l, out_r, out_m;
reg [15:0] inp, inp_m;
always @(posedge clk) if (ce) begin
	if(!stereo) begin
		ch    <= 0;
		inp   <= input_l;
		out_l <= y_clamp;
		out_r <= y_clamp;
	end
	else begin
		ch <= ~ch;
		if(ch) begin
			out_m <= y_clamp;
			inp   <= inp_m;
		end
		else begin
			out_l <= out_m;
			out_r <= y_clamp;
			inp   <= input_l;
			inp_m <= input_r;
		end
	end
end

reg [31:0] out;
always @(posedge clk) if (sample_ce) out <= {out_l, out_r};

assign {output_l, output_r} = out;

endmodule
