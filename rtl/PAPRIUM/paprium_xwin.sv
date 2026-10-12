// MiSTer: paprium_xwin - the MiSTer equivalent of the Pocket SRAM window (MCU 0x08000000) for the
// hook-free CPU MATE buddy. The Pocket board has a 256 KB async SRAM; MiSTer's
// Paprium core has no spare external memory, so this keeps ONLY the parts the buddy program and the firmware glue use,
// compacted into one 26 KB on-chip RAM (M10K, 32-bit wide, byte lanes):
//
//   SRAM bytes (Pocket map)       use                                           window bytes
//   0x10000-0x11FFF   8 KB    PRG-RAM capture $420000-$421FFF (snoop)          0x0000-0x1FFF
//   0x28000-0x29FFF   8 KB    Word RAM mirror terrain $608000-$609FFF          0x2000-0x3FFF
//   0x20000-0x20FFF   4 KB    Word RAM mirror objects $600000-$600FFF          0x4000-0x4FFF
//   0x18000-0x18FFF   4 KB    glue scratch (rate hash 0x18000-0x18BFF)         0x5000-0x5FFF
//   0x24000-0x241FF   512 B   Word RAM mirror records $604000-$6041FF          0x6000-0x61FF
//   0x30000-0x301FF   512 B   Word RAM mirror header $610000-$6101FF           0x6200-0x63FF
//   0x12000-0x121FF   512 B   main's cursor $FF9920 (snoop tap at 0x12000)     0x6400-0x65FF
//
// Every buddy program region (obj, prec, hdr, curt, terr) and every glue access (rate hash,
// sub-init restore records, PRG table copies) lies inside these ranges [V, read from buddy.h,
// the firmware glue]. Writes elsewhere are dropped (acked); reads elsewhere return 0 (acked).
// Same interface as the Pocket's paprium_xram (mc_* MCU client: byte address, store lanes, loads read the
// whole word, ack held until the request drops; sn_* snoop FIFO head, 16-bit "native" words {UB,LB}),
// minus the APF loader and the SRAM pins. clk = clk_sys (the MCU's clock), no clock crossing here.

module paprium_xwin (
	input  wire        clk,
	input  wire        reset,

	input  wire        sn_valid,
	input  wire [16:0] sn_waddr,                   // SRAM 16-bit word address
	input  wire [15:0] sn_data,
	input  wire  [1:0] sn_be,                      // {UB, LB}
	output reg         sn_take,

	input  wire        mc_req,
	input  wire [17:0] mc_addr,                    // SRAM byte address
	input  wire  [3:0] mc_sel,
	input  wire        mc_wr,
	input  wire [31:0] mc_wdata,
	output reg  [31:0] mc_rdata,
	output reg         mc_ack,

	output reg  [31:0] stat_snoop_writes
);

	localparam integer DEPTH = 6656;              // 0x6800 bytes / 4 (26 KB, 13 x 2 M10K)

	function automatic [13:0] wmap(input [17:0] a);   // {hit, 13-bit word index}
		begin
			if      (a[17:13] == 5'b01000)     wmap = {1'b1, 13'h0000 | {2'b00, a[12:2]}};   // 0x10000 PRG
			else if (a[17:13] == 5'b10100)     wmap = {1'b1, 13'h0800 | {2'b00, a[12:2]}};   // 0x28000 terrain
			else if (a[17:12] == 6'b100000)    wmap = {1'b1, 13'h1000 | {3'b000, a[11:2]}};  // 0x20000 objects
			else if (a[17:12] == 6'b011000)    wmap = {1'b1, 13'h1400 | {3'b000, a[11:2]}};  // 0x18000 scratch
			else if (a[17:9]  == 9'b100100000) wmap = {1'b1, 13'h1800 | {6'b000000, a[8:2]}}; // 0x24000 records
			else if (a[17:9]  == 9'b110000000) wmap = {1'b1, 13'h1880 | {6'b000000, a[8:2]}}; // 0x30000 header
			else if (a[17:9]  == 9'b010010000) wmap = {1'b1, 13'h1900 | {6'b000000, a[8:2]}}; // 0x12000 cursor
			else                               wmap = 14'd0;
		end
	endfunction

	(* ramstyle = "M10K, no_rw_check" *) reg [3:0][7:0] ram [0:DEPTH-1];
	reg  [12:0] waddr, raddr;
	reg  [31:0] wdat;
	reg   [3:0] wbe;
	reg         we;
	reg  [3:0][7:0] q;

	always @(posedge clk) begin
		if (we) begin
			if (wbe[0]) ram[waddr][0] <= wdat[7:0];
			if (wbe[1]) ram[waddr][1] <= wdat[15:8];
			if (wbe[2]) ram[waddr][2] <= wdat[23:16];
			if (wbe[3]) ram[waddr][3] <= wdat[31:24];
		end
		q <= ram[raddr];
	end

	wire [13:0] mc_m = wmap(mc_addr);
	wire [13:0] sn_m = wmap({sn_waddr, 1'b0});

	localparam S_IDLE = 2'd0, S_RD1 = 2'd1, S_RD2 = 2'd2;
	reg  [1:0] st = S_IDLE;
	reg        mc_done = 1'b0;
	reg        rd_hit;

	always @(posedge clk) begin
		we      <= 1'b0;
		sn_take <= 1'b0;
		if (!mc_req) begin
			mc_ack  <= 1'b0;
			mc_done <= 1'b0;
		end
		if (reset) begin
			st <= S_IDLE; mc_ack <= 1'b0; mc_done <= 1'b0;
			stat_snoop_writes <= 32'd0;
		end
		else case (st)
			S_IDLE:
				if (mc_req & ~mc_ack & ~mc_done) begin
					if (mc_wr) begin
						we      <= mc_m[13] & (mc_sel != 4'b0000);
						waddr   <= mc_m[12:0];
						wdat    <= mc_wdata;
						wbe     <= mc_sel;
						mc_ack  <= 1'b1;
						mc_done <= 1'b1;
					end
					else begin
						raddr  <= mc_m[12:0];
						rd_hit <= mc_m[13];
						st     <= S_RD1;
					end
				end
				else if (sn_valid & ~sn_take) begin
					we      <= sn_m[13];
					waddr   <= sn_m[12:0];
					wdat    <= {sn_data, sn_data};
					wbe     <= sn_waddr[0] ? {sn_be, 2'b00} : {2'b00, sn_be};
					sn_take <= 1'b1;
					if (stat_snoop_writes != 32'hFFFFFFFF) stat_snoop_writes <= stat_snoop_writes + 1'd1;
				end
			S_RD1: st <= S_RD2;                                 // q <= ram[raddr] this clock
			S_RD2: begin
				mc_rdata <= rd_hit ? q : 32'd0;
				mc_ack   <= mc_req;                             // a dropped request is not acked
				mc_done  <= mc_req;
				st       <= S_IDLE;
			end
			default: st <= S_IDLE;
		endcase
	end

endmodule
