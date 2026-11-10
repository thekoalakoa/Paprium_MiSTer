// Copyright (C) 2026 Marsupial Solutions LLC
// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer: paprium_cram_ddr - MiSTer's stand-in for the Pocket's paprium_cram (cellular PSRAM die 0), on the DDR3
// port that the dropped album (paprium.pcm loader / MD+ ring) left idle.
//
// Die-word view, as on the Pocket: die word w (16 bits) is DDR3 bytes BASE + 2w, 2w+1 (little-endian, the same order
// as MCU_INTERFACE 3.8: u16 / u32 at chip offsets). A 32-bit MCU word or an even/odd die-word pair is 4 aligned bytes,
// so every operation is one 64-bit DDR3 beat with byte enables (BURSTCNT 1).
//   port B  MCU window 0x09000000-0x093FFFFF (xb_region 1): byte address [21:0], lanes, level request, ack held until
//           the request drops (same handshake as paprium_xwin / the Pocket's port B). A dropped request is abandoned.
//   port C  synth stream reads: 21-bit die word address, pulse in, one done pulse with 16 bits.
//   port E  synth echo / dac_buf: 22-bit die word, pair (addr even, 32 bits) or single (bits 15:0); posted write
//           (e_wbusy while held), read pulse -> done pulse with 32 bits (single: bits 15:0).
// Priority E-write > E-read > C-read > B, with B aged ahead after B_AGE clocks so the NEORV32's 127-clock bus timeout
// cannot be reached by stream traffic alone. One operation in flight. DDR3 latency is NOT ESTABLISHED on the target
// (bench G-M5 with jitter and scaler traffic is still owed). clk = clk_sys = DDRAM_CLK.
module paprium_cram_ddr #(
	parameter [28:0] BASE_QW = 29'h0700_0000,   // 64-bit word base: byte 0x3800_0000 (the old album blob base)
	parameter integer B_AGE  = 24
) (
	input  wire        clk,
	input  wire        reset,
	input  wire        fw_done,   // 030 CRAM dig: starve E/C, B_AGE=0 while ~fw_done

	input  wire        b_req,
	input  wire [21:0] b_addr,
	input  wire  [3:0] b_sel,
	input  wire        b_wr,
	input  wire [31:0] b_wdata,
	output reg  [31:0] b_rdata,
	output reg         b_ack,

	input  wire        c_rd,
	input  wire [20:0] c_raddr,
	output reg         c_rd_done,
	output reg  [15:0] c_rdata,

	input  wire        e_wr,
	input  wire [21:0] e_waddr,
	input  wire        e_wpair,
	input  wire [31:0] e_wdata,
	input  wire        e_rd,
	input  wire [21:0] e_raddr,
	input  wire        e_rpair,
	output reg         e_rd_done,
	output reg  [31:0] e_rdata,
	output wire        e_wbusy,

	input  wire        DDRAM_BUSY,
	output wire  [7:0] DDRAM_BURSTCNT,
	output reg  [28:0] DDRAM_ADDR,
	input  wire [63:0] DDRAM_DOUT,
	input  wire        DDRAM_DOUT_READY,
	output reg         DDRAM_RD,
	output reg  [63:0] DDRAM_DIN,
	output reg   [7:0] DDRAM_BE,
	output reg         DDRAM_WE,

	output reg  [31:0] stat_ops,
	output wire  [7:0] stat_bage   // DDRFLAGS: observation only (b_age)
);
	assign DDRAM_BURSTCNT = 8'd1;

	// pending registers
	reg        ew_p = 0, er_p = 0, cr_p = 0;
	reg [21:0] ew_a, er_a; reg ew_pair, er_pair; reg [31:0] ew_d;
	reg [20:0] cr_a;
	assign e_wbusy = ew_p;

	reg  [7:0] b_age = 0;
	assign stat_bage = b_age;
	reg        b_done = 0;        // ack given, waiting for the request to drop

	localparam IDLE = 2'd0, ISSUE = 2'd1, WAITRD = 2'd2;
	reg [1:0] st = IDLE;
	reg [1:0] who;                // 0 B, 1 C, 2 E-read, 3 E-write
	reg [2:0] lane;               // byte offset in the 64-bit word of the 32-bit group (0 or 4) / half (+2)
	reg       pair_q;

	// die word -> {qword, byte offset}
	function automatic [31:0] qw(input [22:0] byteoff); qw = {9'd0, byteoff[22:3]}; endfunction

	always @(posedge clk) begin
		c_rd_done <= 1'b0;
		e_rd_done <= 1'b0;
		if (!b_req) begin b_ack <= 1'b0; b_done <= 1'b0; end
		if (e_wr & fw_done) begin ew_p <= 1'b1; ew_a <= e_waddr; ew_pair <= e_wpair; ew_d <= e_wdata; end
		if (e_rd & fw_done) begin er_p <= 1'b1; er_a <= e_raddr; er_pair <= e_rpair; end
		if (c_rd & fw_done) begin cr_p <= 1'b1; cr_a <= c_raddr; end
		if (b_req & ~b_ack & ~b_done & (b_age != 8'hFF)) b_age <= b_age + 1'd1;
		if (!b_req) b_age <= 0;

		if (reset) begin
			st <= IDLE; DDRAM_RD <= 0; DDRAM_WE <= 0; ew_p <= 0; er_p <= 0; cr_p <= 0;
			b_ack <= 0; b_done <= 0; stat_ops <= 0;
		end
		else case (st)
			IDLE: begin
				reg [22:0] bo;
				if (b_req & ~b_ack & ~b_done & ((b_age >= B_AGE) | ~fw_done | ~(ew_p | er_p | cr_p))) begin
					who <= 2'd0; bo = {1'b0, b_addr[21:2], 2'b00}; lane <= bo[2:0];
					DDRAM_ADDR <= BASE_QW + qw(bo);
					DDRAM_DIN  <= {b_wdata, b_wdata};
					DDRAM_BE   <= bo[2] ? {b_sel, 4'b0} : {4'b0, b_sel};
					DDRAM_WE   <= b_wr & (b_sel != 0); DDRAM_RD <= ~b_wr;
					if (b_wr & (b_sel == 0)) begin b_ack <= 1'b1; b_done <= 1'b1; end
					else st <= ISSUE;
				end
				else if (ew_p & fw_done) begin
					who <= 2'd3; bo = {ew_a, 1'b0}; lane <= bo[2:0];
					DDRAM_ADDR <= BASE_QW + qw(bo);
					DDRAM_DIN  <= ew_pair ? {ew_d, ew_d} : {4{ew_d[15:0]}};
					DDRAM_BE   <= ew_pair ? (bo[2] ? 8'hF0 : 8'h0F) : (8'h03 << bo[2:0]);
					DDRAM_WE   <= 1'b1; st <= ISSUE;
				end
				else if (er_p & fw_done) begin
					who <= 2'd2; bo = {er_a, 1'b0}; lane <= bo[2:0]; pair_q <= er_pair;
					DDRAM_ADDR <= BASE_QW + qw(bo); DDRAM_BE <= 8'hFF; DDRAM_RD <= 1'b1; st <= ISSUE;
				end
				else if (cr_p & fw_done) begin
					who <= 2'd1; bo = {1'b0, cr_a, 1'b0}; lane <= bo[2:0];
					DDRAM_ADDR <= BASE_QW + qw(bo); DDRAM_BE <= 8'hFF; DDRAM_RD <= 1'b1; st <= ISSUE;
				end
			end
			ISSUE: if (!DDRAM_BUSY) begin
				DDRAM_RD <= 1'b0; DDRAM_WE <= 1'b0;
				if (stat_ops != 32'hFFFFFFFF) stat_ops <= stat_ops + 1'd1;
				if (DDRAM_WE) begin
					if ((who == 2'd3) & ~e_wr) ew_p <= 1'b0;
					else if (b_req) begin b_ack <= 1'b1; b_done <= 1'b1; end   // dropped: no ack
					st <= IDLE;
				end
				else st <= WAITRD;
			end
			WAITRD: if (DDRAM_DOUT_READY) begin
				reg [63:0] sh;
				sh = DDRAM_DOUT >> {lane, 3'b000};
				case (who)
					2'd0: if (b_req) begin b_rdata <= sh[31:0]; b_ack <= 1'b1; b_done <= 1'b1; end
					2'd1: begin c_rdata <= sh[15:0]; c_rd_done <= 1'b1; if (~c_rd) cr_p <= 1'b0; end
					2'd2: begin e_rdata <= pair_q ? sh[31:0] : {16'd0, sh[15:0]}; e_rd_done <= 1'b1; if (~e_rd) er_p <= 1'b0; end
					default: ;
				endcase
				st <= IDLE;
			end
			default: st <= IDLE;
		endcase
	end
endmodule
