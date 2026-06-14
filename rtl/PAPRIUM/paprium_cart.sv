module paprium_cart
(
	input             clk,
	input             reset,
	input             enable,

	input      [23:1] cart_addr,
	input      [15:0] cart_data_wr,
	input             cart_cs,
	input             cart_oe,
	input             cart_lwr,
	input             cart_uwr,
	input             cart_time,
	input             stream_read_ack,

	output     [15:0] cart_data,
	output            mailbox_cs,
	output            stream_cs,
	output     [24:1] stream_addr,
	output            md_reset,

	output     [24:1] mem_addr,
	output     [15:0] mem_din,
	input      [15:0] mem_dout,
	output            mem_wrl,
	output            mem_wrh,
	output            mem_req,
	input             mem_ack
);

	McuBus mcu;
	CpuBus cpu;

	assign cpu.dato = cart_data_wr;
	assign cpu.addr = {cart_addr, 1'b0};
	assign cpu.as = cart_cs;
	assign cpu.oe = cart_oe;
	assign cpu.we_hi = cart_uwr;
	assign cpu.we_lo = cart_lwr;
	assign cpu.ce_hi = 0;
	assign cpu.ce_lo = enable & cart_cs;
	assign cpu.tim = enable & cart_time;
	assign cpu.vclk = 0;
	assign cpu.map.ramdp = cpu.ce_lo & (cpu.addr < 24'h002000);
	assign cpu.map.sdram = 0;
	assign cpu.map.flash = 0;

	assign mailbox_cs = cpu.map.ramdp;
	assign stream_cs = enable & cart_cs & cart_oe & sdram_en &
	                   (cpu.addr[23:13] == 11'd3);

	reg [20:0] stream_ptr;
	always @(posedge clk) begin
		if(reset) stream_ptr <= 0;
		else if(mcu.ce && (mcu.we != 0) && mcu.map.fpgio_sptr)
			stream_ptr <= mcu.dato[20:0];
		else if(stream_read_ack)
			stream_ptr <= stream_ptr + 2'd2;
	end

	assign stream_addr = 24'h400000 + {{4{1'b0}}, stream_ptr[20:1]};

	wire [31:0] mcu_dati_fpgio;
	wire [31:0] mcu_dati_ramdp;
	wire [31:0] mcu_dati_mem;
	wire [15:0] cpu_dati_ramdp;
	wire mcu_ack_mem;
	wire sdram_en;

	wire [31:0] mcu_dati =
		mcu.map.fpgio ? mcu_dati_fpgio :
		mcu.map.ramdp ? mcu_dati_ramdp :
		(mcu.map.flash | mcu.map.sdram | mcu.map.bram) ? mcu_dati_mem :
		(mcu.map.sfx | mcu.map.mdp) ? 32'h00000000 :
		32'hffffffff;

	wire mcu_ack =
		(mcu.map.flash | mcu.map.sdram | mcu.map.bram) ? mcu_ack_mem :
		1'b1;

	wire [15:0] wram_dato;
	wire [15:0] wram_dati;
	wire [18:0] wram_addr;
	wire [1:0] wram_we;
	MemBus wram;

	assign wram_dati = wram.dati;
	assign wram_addr = wram.addr[18:0];
	assign wram_we = wram.we;

	mcu_core mcu_inst
	(
		.clk(clk),
		.rst(reset | ~enable),
		.mcu(mcu),
		.mcu_dati(mcu_dati),
		.mcu_ack(mcu_ack),
		.wram(wram),
		.wram_dato(wram_dato),
		.gpio_o(),
		.gpio_i(32'd0),
		.uart_tx(),
		.uart_rx(1'b1),
		.debug_bus_ack(),
		.debug_bus_addr(),
		.debug_bus_wdata(),
		.debug_bus_we(),
		.debug_bus_target()
	);

	paprium_wram wram_inst
	(
		.clk(clk),
		.addr(wram_addr[14:1]),
		.dati(wram_dati),
		.we(wram_we),
		.dato(wram_dato)
	);

	fpgio fpgio_inst
	(
		.mcu(mcu),
		.md_srst(reset),
		.mcu_dati(mcu_dati_fpgio),
		.md_rst(md_reset),
		.exit(),
		.sdram_en(sdram_en),
		.debug_ctrl_write(),
		.debug_ctrl_value()
	);

	ramdp_io ramdp_inst
	(
		.mcu(mcu),
		.cpu(cpu),
		.mcu_dati(mcu_dati_ramdp),
		.cpu_dati(cpu_dati_ramdp),
		.debug_ramdp_write(),
		.debug_ramdp_vector_write(),
		.debug_ramdp_addr(),
		.debug_ramdp_data(),
		.debug_cpu_we_act(),
		.debug_cpu_write()
	);

	assign cart_data = cpu_dati_ramdp;

	paprium_mcu_mem mem_inst
	(
		.clk(clk),
		.reset(reset | ~enable),
		.mcu(mcu),
		.mcu_ack(mcu_ack_mem),
		.mcu_dati(mcu_dati_mem),
		.mem_addr(mem_addr),
		.mem_din(mem_din),
		.mem_dout(mem_dout),
		.mem_wrl(mem_wrl),
		.mem_wrh(mem_wrh),
		.mem_req(mem_req),
		.mem_ack(mem_ack)
	);

endmodule
