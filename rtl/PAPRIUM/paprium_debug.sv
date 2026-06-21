// ---------------------------------------------------------------------------
// Paprium cart-bus diagnostic taps (new MegaDrive core)
// ---------------------------------------------------------------------------
// Watches the 68k<->cartridge bus (clk_sys) and accumulates live state into a
// 448-bit `words` bundle (v2..v15) that paprium_ddr_diag ships to DDR3 for SSH
// readback. Everything here is observed at the cartridge boundary - no MBUS or
// MCU-internal signals needed.
//
// Read transaction model: a 68k read holds cart_cs & cart_oe for several cycles
// until the cartridge returns data; the address is stable for the whole read.
// We latch the address on the read's RISING edge and the data on its FALLING
// edge (when cart_data holds the just-completed result).
//
// word map (read each with `devmem 0x300000NN 32`):
//   v2  0x08  last 68k read byte addr (where it is executing / reading)
//   v3  0x0C  last 68k read in 0x000-0x3FF (vector/low region; the 0x00F0 area)
//   v4  0x10  exception-vector read count (byte 0x08-0x3F) = fault counter
//   v5  0x14  last 68k WRITE {addr[16:1],data16} = mailbox command (cpuWr)
//   v6  0x18  68k write count (0 = never commands MCU)
//   v7  0x1C  MCU->RAMDP {last write longword addr[10:0], write count[15:0]}
//   v8  0x20  stream-window (0xC000-0xFFFF) read count
//   v9  0x24  last read DATA of the last_fetch
//   v10 0x28  mailbox (0x1FE0-0x1FFF) read count
//   v11 0x2C  MCU->RAMDP last write data
//   v12 0x30  MCU port-2 write count
//   v13 0x34  MCU port-2 last write word address
//   v14 0x38  MCU->RAMDP status longword write at byte 0x1FE4-0x1FE7
//   v15 0x3C  MCU->RAMDP reg_cmd longword write at byte 0x1FE8-0x1FEB
// ---------------------------------------------------------------------------

module paprium_debug
(
	input              clk,            // clk_sys
	input              enable,         // paprium_active

	input       [23:1] cart_addr,
	input       [15:0] cart_data,      // cartridge read result (cart_data_rom)
	input       [15:0] cart_data_wr,
	input              cart_cs,
	input              cart_oe,
	input              cart_lwr,
	input              cart_uwr,

	// MCU port-2 (flash/workspace) write taps
	input       [24:1] mcu_mem_addr,
	input       [15:0] mcu_mem_din,
	input              mcu_mem_wrl,
	input              mcu_mem_wrh,

	// MCU -> RAMDP writes. Address is RAMDP longword index (byte addr[12:2]).
	input              ramdp_write,
	input       [10:0] ramdp_addr,
	input       [31:0] ramdp_data,

	output     [447:0] words
);
	wire [23:0] baddr = {cart_addr, 1'b0};

	wire rd = cart_cs & cart_oe;
	wire wr = cart_cs & (cart_lwr | cart_uwr);

	reg rd_d, wr_d;

	reg [23:0] last_fetch;
	reg [23:0] last_low_fetch;
	reg [15:0] vec_rd_cnt;
	reg [31:0] last_write;
	reg [15:0] wr_cnt;
	reg [15:0] patch_8104;
	reg [15:0] stream_cnt;
	reg [15:0] last_data;
	reg [15:0] mailbox_cnt;
	reg [23:0] last_game_fetch;
	reg [23:0] last_stream_fetch;
	reg [31:0] last_vec;
	reg [15:0] rd_cnt;
	reg [15:0] flags;

	// MCU port-2 write taps (is the MCU decompressing into the workspace?)
	reg [15:0] mcu_wr_cnt;
	reg [24:1] last_mcu_wr_addr;
	reg [15:0] last_mcu_wr_data;
	reg        mcu_wr_d;
	wire       mcu_wr = mcu_mem_wrl | mcu_mem_wrh;

	reg [15:0] ramdp_wr_cnt;
	reg [10:0] last_ramdp_wr_addr;
	reg [31:0] last_ramdp_wr_data;
	reg [31:0] status_wr_data;
	reg [31:0] regcmd_wr_data;

	// byte 0x81104 -> cart_addr (word) 0x40882
	localparam [23:1] EMU_CHECK_WADDR = 23'h40882;
	localparam [10:0] STATUS_LWADDR   = 11'h7F9; // byte 0x1FE4..0x1FE7
	localparam [10:0] REG_CMD_LWADDR  = 11'h7FA; // byte 0x1FE8..0x1FEB, reg_cmd at 0x1FEA

	wire stream_win = (baddr[23:14] == 10'd3);                       // byte 0xC000-0xFFFF
	wire mailbox_rgn = (baddr >= 24'h001FE0) & (baddr < 24'h002000); // 0x1FE0-0x1FFF
	wire vec_rgn     = (baddr >= 24'h000008) & (baddr < 24'h000040); // CPU exc vectors 2..15

	always @(posedge clk) begin
		if (!enable) begin
			rd_d <= 0; wr_d <= 0;
			last_fetch <= 0; last_low_fetch <= 0; vec_rd_cnt <= 0;
			last_write <= 0; wr_cnt <= 0; patch_8104 <= 0; stream_cnt <= 0;
			last_data <= 0; mailbox_cnt <= 0; last_game_fetch <= 0;
			last_stream_fetch <= 0; last_vec <= 0; rd_cnt <= 0; flags <= 0;
			mcu_wr_cnt <= 0; last_mcu_wr_addr <= 0; last_mcu_wr_data <= 0; mcu_wr_d <= 0;
			ramdp_wr_cnt <= 0; last_ramdp_wr_addr <= 0; last_ramdp_wr_data <= 0;
			status_wr_data <= 0; regcmd_wr_data <= 0;
		end
		else begin
			rd_d <= rd;
			wr_d <= wr;

			// MCU port-2 writes: workspace decompression / flash patches.
			mcu_wr_d <= mcu_wr;
			if (mcu_wr & ~mcu_wr_d) begin
				if (mcu_wr_cnt != 16'hffff) mcu_wr_cnt <= mcu_wr_cnt + 16'd1;
				last_mcu_wr_addr <= mcu_mem_addr;
				last_mcu_wr_data <= mcu_mem_din;
			end

			if (ramdp_write) begin
				if (ramdp_wr_cnt != 16'hffff) ramdp_wr_cnt <= ramdp_wr_cnt + 16'd1;
				last_ramdp_wr_addr <= ramdp_addr;
				last_ramdp_wr_data <= ramdp_data;
				if (ramdp_addr == STATUS_LWADDR) status_wr_data <= ramdp_data;
				if (ramdp_addr == REG_CMD_LWADDR) regcmd_wr_data <= ramdp_data;
			end

			// Read rising edge: latch where the 68k is reading.
			if (rd & ~rd_d) begin
				last_fetch <= baddr;
				if (rd_cnt != 16'hffff) rd_cnt <= rd_cnt + 16'd1;

				if (baddr < 24'h000400) last_low_fetch    <= baddr;
				if (stream_win)         last_stream_fetch <= baddr;
				if (|baddr[23:17])      last_game_fetch   <= baddr;   // >= 0x20000

				if (vec_rgn)     if (vec_rd_cnt  != 16'hffff) vec_rd_cnt  <= vec_rd_cnt  + 16'd1;
				if (stream_win)  if (stream_cnt  != 16'hffff) stream_cnt  <= stream_cnt  + 16'd1;
				if (mailbox_rgn) if (mailbox_cnt != 16'hffff) mailbox_cnt <= mailbox_cnt + 16'd1;
			end

			// Read falling edge: cart_data now holds the completed result.
			if (rd_d & ~rd) begin
				last_data <= cart_data;
				if (last_fetch == {EMU_CHECK_WADDR, 1'b0}) patch_8104 <= cart_data;
				if (last_fetch < 24'h000400) last_vec <= {8'd0, last_fetch[7:0], cart_data};
			end

			// Write: the 68k -> mailbox command path (cpuWr).
			if (wr & ~wr_d) begin
				last_write <= {baddr[16:1], cart_data_wr};
				if (wr_cnt != 16'hffff) wr_cnt <= wr_cnt + 16'd1;
				if (mailbox_rgn) flags[0] <= 1'b1;
			end
		end
	end

	assign words = {
		regcmd_wr_data,                  // v15 0x3C  reg_unk4/reg_cmd longword
		status_wr_data,                  // v14 0x38  reg_status_1/reg_status_2 longword
		{8'd0,  last_mcu_wr_addr},       // v13 0x34  MCU last workspace write word-addr
		{16'd0, mcu_wr_cnt},             // v12 0x30  MCU port-2 write count
		last_ramdp_wr_data,              // v11 0x2C  MCU->RAMDP last write data
		{16'd0, mailbox_cnt},            // v10 0x28
		{16'd0, last_data},              // v9  0x24
		{16'd0, stream_cnt},             // v8  0x20
		{5'd0, last_ramdp_wr_addr, ramdp_wr_cnt}, // v7 0x1C
		{16'd0, wr_cnt},                 // v6  0x18
		last_write,                      // v5  0x14
		{16'd0, vec_rd_cnt},             // v4  0x10
		{8'd0,  last_low_fetch},         // v3  0x0C
		{8'd0,  last_fetch}              // v2  0x08
	};

endmodule
