// Changes: Copyright (C) 2026 Marsupial Solutions LLC (GPL-3.0-or-later)
// fx68k-soak: pin-compatible wrapper around ijor/FX68K for paprium-pocket Nuked md_board.
// Measurement / soak branch only - NOT a shipping CPU swap.
// flicker A/B VCLK-enPhi on 0.2.1 (isolation: Nuked clean).
// ONE VARIABLE vs lead-1 free-run A4DEABF0: enPhi from VCLK edge-detect (CLK=VCLK);
// LOCKED pads 0298/AA50 unchanged. Prior VCLK 3D7CED75 was on 0.2.0 pre-animation-fix.
// - KEEP: ADDRESS=eab[23:1]; ADDRESS_z=~addrOe
// - KEEP: DATA_o=oEdb, iEdb(DATA_i); DATA_z=ASn|eRWn
// - KEEP: FC={FC2,FC1,FC0}; FC_z=ASn
// ALT1+VPA: BR/BGACK/VPA flopped on enPhi2 (vs ALT1 E98AAB3E)
// 1-tick DTACK: MCLK-flop DTACK -> FX DTACKn (ONE VARIABLE vs ALT1+VPA)
// - KEEP: *n pass-through except BRn/BGACKn=br_d/bgack_d, VPAn=vpa_d; BG=BGn; RW_z=eRWn&ASn; strobe_z=ASn
// - KEEP: HALTn=1'b1; HALT_pull=~oHALTEDn; cold pwrUp; fx_reset
`timescale 1ns / 1ns

module fx68k_m68kcpu_wrap (
	input MCLK,
	input CLK,
	input CART_LOADED,	// FXALIGN1P ITEM 1': clk_sys-domain sticky 'first cart download done' (MegaDrive.sv fx_cart_loaded)
	input VPA,
	input BR,
	input BGACK,
	input DTACK,
	input [2:0] IPL,
	input BERR,
	input RESET_i,
	input RESET_x_i,	// PASS10: board RESET from every puller except this CPU (active low); ~RESET_i == ~RESET_x_i | RESET_pull
	output RESET_pull,
	input HALT_i,
	output HALT_pull,
	input [15:0] DATA_i,
	output [15:0] DATA_o,
	output DATA_z,
	output E_CLK,
	output BG,
	output [2:0] FC,
	output FC_z,
	output RW,
	output RW_z,
	output [22:0] ADDRESS,
	output ADDRESS_z,
	output AS,
	output LDS,
	output UDS,
	output strobe_z,
	// PASS6: registered cold pwrUp (same flop that gates enPhi/fx_reset). Fans out only
	// through this pin into a clk_sys sticky for cartridge EEPROM idle-during-cold.
	output pwrUp_o
);

	localparam [15:0] COLD_PWRUP_CYCLES = 16'd4095;
	// pocket (0.3.0 stage 1, G1 fit round 2): maxfan 16. Since the warm-RESET fix pwrUp gates enPhi1 / enPhi2 directly
	// (~120 loads at the fit), and its route into fx_reset -> FC_z -> the arbiter's INTAK decode -> VD set the vd_bus class
	// on round-1 seed 4 (-0.793 ns, slow 85C). The copies are the same register (exact); each lies nearer its loads.
	(* maxfan = 16 *) reg pwrUp = 1'b1;
	assign pwrUp_o = pwrUp;
	reg [15:0] coldCnt = 16'd0;
	always @(posedge MCLK) begin
		if (pwrUp) begin
			if (coldCnt == COLD_PWRUP_CYCLES)
				pwrUp <= 1'b0;
			else
				coldCnt <= coldCnt + 16'd1;
		end
	end

	// FXALIGN1P ITEM 1' (FX68K-only power-on hold). Mirrors Pocket 0.2.2 core_top.sv:709-735:
	// loading_74a = ~dataslot_allcomplete | rom_download, synch_3 into clk_md, which holds the
	// console (and so this CPU) from power-on until the first cartridge has landed. On MiSTer only
	// the CPU gets the hold; md_reset/VDP/board run (FXALIGN123 held the whole board = no video).
	// CART_LOADED is sticky on clk_sys; 2-flop synchronizer into MCLK, second stage sticky, so
	// fx_hold has exactly one clean deassert edge. fx_hold feeds fx_reset -> fx68k extReset.
	(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *) reg fxh_sync1 = 1'b0;
	(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *) reg fxh_sync1b = 1'b0; // PASS10: third stage
	(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *) reg fxh_sync2 = 1'b0;
	always @(posedge MCLK) begin
		fxh_sync1 <= CART_LOADED;
		fxh_sync1b <= fxh_sync1;
		fxh_sync2 <= fxh_sync2 | fxh_sync1b;
	end
	wire fx_hold = ~fxh_sync2;

	// PASS10: fx_reset was ~RESET_i | pwrUp | fx_hold, one LUT in front of FC_z, and that LUT plus its routing put
	// oReset / fxh_sync2 -> FC_z -> VDP CAS -> cart CE0 -> cartridge rom_addr over budget at 107 MHz (pass 9 fit).
	// The three terms that belong to this CPU (its own RESET output oReset, the cold pwrUp and the cart-load hold) are
	// all flops on MCLK, so one flop fed with their next-state values holds exactly oReset | pwrUp | fx_hold on every
	// MCLK. RESET from the other pullers (VDP/arbiter, ext_vres) arrives separately on RESET_x_i, so
	// fx_reset = ~RESET_x_i | fx_rst_q is the same value as before on every cycle, one logic level shorter.
	// fxh_sync1b (above) keeps stage 1 of the CART_LOADED synchronizer feeding a single flop; the hold therefore
	// releases one MCLK (9.3 ns) later after an asynchronous CART_LOADED edge, nothing else moves.
	wire oReset_nx;
	wire pwrUp_nx   = pwrUp & (coldCnt != COLD_PWRUP_CYCLES);
	wire fx_hold_nx = ~(fxh_sync2 | fxh_sync1b);
	wire fx_rst_nx  = oReset_nx | pwrUp_nx | fx_hold_nx;
	(* preserve *) reg fx_rst_q  = 1'b1; // == oReset | pwrUp | fx_hold
	(* preserve *) reg fx_rst_fc = 1'b1; // same value, private copy placed by FC_z
	always @(posedge MCLK) begin
		fx_rst_q  <= fx_rst_nx;
		fx_rst_fc <= fx_rst_nx;
	end
	wire fx_reset    = ~RESET_x_i | fx_rst_q;
	wire fx_reset_fc = ~RESET_x_i | fx_rst_fc;
	wire fx_haltn = 1'b1;

	// VCLK-synced enPhi (CLK port = VCLK from md_board); mutually exclusive one-hots
	reg clk_r;
	always @(posedge MCLK) clk_r <= CLK;
	wire rise = CLK & ~clk_r;
	wire mid  = ~CLK & clk_r;
	// The phases stop only during the cold pwrUp, never during a warm RESET: FX68K's reset is
	// synchronous and needs enPhi1/enPhi2 running while extReset is high (tState keeps ticking
	// so T1 loads the reset micro-address and the bus-cycle latch clears on Phi2). With the
	// phases stopped by fx_reset the release resumed the cut instruction or replayed the cut
	// bus cycle before the vector read. Identical to ~fx_reset whenever RESET_i is high.
	wire enPhi1 = ~pwrUp & rise;
	wire enPhi2 = ~pwrUp & mid;


	// ALT1+VPA: BR/BGACK/VPA enPhi2-register (stable at next enPhi1); ONE VARIABLE vs ALT1
	reg br_d, bgack_d, vpa_d;
	always @(posedge MCLK) begin
		if (fx_reset) begin
			br_d <= 1'b1;
			bgack_d <= 1'b1;
			vpa_d <= 1'b1;
		end else if (enPhi2) begin
			br_d <= BR;
			bgack_d <= BGACK;
			vpa_d <= VPA;
		end
	end

	// 1-tick DTACK wrap: sample DTACK every MCLK; feed FX from flop
	reg dtack_d;
	always @(posedge MCLK) begin
		if (fx_reset) dtack_d <= 1'b1;
		else dtack_d <= DTACK;
	end
	wire ASn, LDSn, UDSn, eRWn, VMAn;
	wire BGn, oRESETn, oHALTEDn;
	wire FC0, FC1, FC2;
	wire [23:1] eab;
	wire [15:0] oEdb;
	wire addrOe;

	fx68k cpu (
		.clk(MCLK),
		.HALTn(fx_haltn),
		.extReset(fx_reset),
		.pwrUp(pwrUp),
		.enPhi1(enPhi1),
		.enPhi2(enPhi2),
		.eRWn(eRWn),
		.ASn(ASn),
		.LDSn(LDSn),
		.UDSn(UDSn),
		.E(E_CLK),
		.VMAn(VMAn),
		.FC0(FC0),
		.FC1(FC1),
		.FC2(FC2),
		.BGn(BGn),
		.oRESETn(oRESETn),
		.oHALTEDn(oHALTEDn),
		.oResetNx(oReset_nx),
		.DTACKn(dtack_d),
		.VPAn(vpa_d),
		.BERRn(BERR),
		.BRn(br_d),
		.BGACKn(bgack_d),
		.IPL0n(IPL[0]),
		.IPL1n(IPL[1]),
		.IPL2n(IPL[2]),
		.iEdb(DATA_i),
		.oEdb(oEdb),
		.eab(eab),
		.addrOe(addrOe)
	);

	// FXALIGN1P ITEM 1': during the hold the board sees no bus cycle (strobes inactive, read)
	assign AS = ASn | fx_hold;
	assign LDS = LDSn | fx_hold;
	assign UDS = UDSn | fx_hold;
	assign RW = eRWn | fx_hold;
	assign ADDRESS = eab[23:1];
	assign DATA_o = oEdb;
	assign DATA_z = ASn | eRWn | fx_hold;
	assign ADDRESS_z = ~addrOe;
	assign RW_z = eRWn & ASn;
	assign strobe_z = ASn;
	assign FC = {FC2, FC1, FC0};
	// FC HOLD: the real m68kcpu ties the FC tri-state to the same enable as AS/UDS/LDS
	// (68k.v:2045/2235, :5683/5698/5713), so FC never floats while AS is asserted. FC_z = ASn
	// floated it at every cycle end; md_board.v:837-838 ORs that into FC0/FC1 combinationally
	// while md_board.v:784-786 still holds AS low for one MCLK2, ym6045.v:632-633/820 reads
	// FC1&FC0 as an interrupt acknowledge with no AS term, and ym7101.v:2395/2582 clears the
	// pending HINT/VINT. asn_d covers the boards AS-register lag so FC can only float once
	// the boards AS has actually gone high; the BG/BGACK terms reproduce the netlists own
	// tri-state states. Sim: 71 lost IRQs/frame -> 0; on a DMA frame 53 lost -> 0.
	reg asn_d = 1'b1;
	always @(posedge MCLK) asn_d <= ASn;
	assign FC_z = ASn & asn_d & (~BGn | ~bgack_d | fx_reset_fc); // PASS10: fx_reset_fc == fx_reset
	assign BG = BGn;
	assign RESET_pull = ~oRESETn;
	assign HALT_pull = ~oHALTEDn;

endmodule
