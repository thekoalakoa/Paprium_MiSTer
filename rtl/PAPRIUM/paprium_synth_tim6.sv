// Copyright (C) 2026 Marsupial Solutions LLC
// SPDX-License-Identifier: GPL-3.0-or-later
// pocket: stage 5 (0.3.0, item S2, block B2) - paprium_synth_tim6: the cart chip's TIM6 block decision, one TIM6
// instant at a time (combinational). It is the scheduler half of TIM6_DAC_IRQHandler 0x080153DC -> audio_block_irq
// 0x08019CBC -> audio_block_dt 0x08019BDC, statement for statement [V listing 0x08019BDC-0x08019D4A], with
// wave_envelope_block + mix_block (the block itself) replaced by "mix = 1 at this index" (the block runs atomically
// after the decision, allow-list B40).
//
// The chip's words (G = 0x2001341C, all u16 in the chip):
//   path  G+0x06 0x20013422  0 = cart-DAC (DT) path audio_block_dt, 1 = YM-DAC path (CONFIG writes 0 or 1 only)
//   half  G+0x0C 0x20013428  HALF: 0 (before the first audio_config), 800 (YM NTSC) or 960 (DT, YM PAL)
//   nblk  G+0x0E 0x2001342A  NBLK: 0, 5 or 6
//   blk   G+0x10 0x2001342C  BLKCNT, blocks mixed mod 4,096
//   fp    G+0x18 0x20013434  frame_pending (the tick sets it, bgm_module_init and this decision clear it)
//   cur   G+0x36 0x20013452  cur_half
//   fill  G+0x38 0x20013454  fill_half
//   cnt   G+0x3A 0x20013456  blocks of this half / frame (0..NBLK, or 0xFF after audio_config)
// pos = dma_consumed(2, HALF << 1): the DT DMA position (0..1,919) at this instant, 0 when HALF = 0 or the DMA is
// stopped (dma_consumed clamps 0 - NDTR to 0). The chip reads both rings' positions and re-runs audio_config if they are
// more than 32 apart (0x08019BF8-0x08019C00 -> 0x08019C88); here both rings are one index, so that branch cannot be
// taken and is not built (the chip's own condition is false for equal positions).
//
// Domain (what the scheduler can hold): path 0 / 1, half in {0, 800, 960}, nblk in {0, 5, 6}, cnt 8 bits (the chip's
// u16 never leaves 0..NBLK or 0xFF), fill / cur / fp 0 / 1, pos 0..1,919. Inside it every output equals the chip's.
//
// Clock: none (pure function); paprium_synth_sched registers the result.

module paprium_synth_tim6 (
	input             path,
	input      [10:0] half,
	input       [2:0] nblk,
	input      [11:0] blk,
	input             fp,
	input             cur,
	input             fill,
	input       [7:0] cnt,
	input      [10:0] pos,

	output reg        mix,                         // wave_envelope_block + mix_block run at this instant
	output reg [10:0] idx,                         // the block's first dac_buf entry: HALF x fill + 160 x cnt
	output reg        incomplete,                  // the chip's u16 at 0x200070D8 += 1 (a DT half left incomplete)
	output reg [11:0] blk_o,
	output reg        fp_o,
	output reg        cur_o,
	output reg        fill_o,
	output reg  [7:0] cnt_o
);

	wire [7:0]  nb8 = {5'd0, nblk};

	// HALF x fill + 160 x cnt (cnt < NBLK <= 6 whenever a block is mixed; the chip's 32-bit sum, < 1,920 here)
	function automatic [10:0] bidx(input [10:0] h, input f, input [7:0] c);
		bidx = (f ? h : 11'd0) + {c[3:0], 7'd0} + {2'd0, c[3:0], 5'd0};
	endfunction

	reg        c1;
	reg  [7:0] k1;

	always @(*) begin
		mix = 1'b0; idx = 11'd0; incomplete = 1'b0;
		blk_o = blk; fp_o = fp; cur_o = cur; fill_o = fill; cnt_o = cnt;
		c1 = 1'b0; k1 = cnt;
		if (!path) begin
			// ---- audio_block_dt ----
			// 0x08019C02-0x08019C0C: r3 = (pos >= HALF), unsigned
			c1 = (pos >= half);
			k1 = cnt;
			if (cur != c1) begin
				// 0x08019C12-0x08019C24: a half change with fewer than NBLK blocks counts as incomplete
				if (cnt < nb8) incomplete = 1'b1;
				cur_o  = c1;
				fill_o = (pos < half);
				k1     = 8'd0;
			end
			cnt_o = k1;
			if (half == 11'd0) begin
				// 0x08019C34-0x08019C3E: HALF = 0 only counts
				if (k1 < nb8) cnt_o = k1 + 8'd1;
			end
			else if (k1 < nb8) begin
				// 0x08019C44-0x08019C80
				mix   = 1'b1;
				idx   = bidx(half, fill_o, k1);
				cnt_o = k1 + 8'd1;
				blk_o = blk + 12'd1;
			end
		end
		else begin
			// ---- audio_block_irq, YM-DAC path ----
			k1 = cnt;
			if (fp && (cnt < nb8)) begin
				// 0x08019CF0-0x08019CFC: the old frame's next block (frame_pending stays)
				if (half != 11'd0) begin
					mix   = 1'b1;
					idx   = bidx(half, fill, cnt);
					cnt_o = cnt + 8'd1;
					blk_o = blk + 12'd1;
				end
				else cnt_o = cnt + 8'd1;                    // 0x08019CEA
			end
			else begin
				if (fp) begin
					// 0x08019D40-0x08019D48: the new frame starts at dac_buf_L[0]
					fp_o = 1'b0; cur_o = 1'b0; fill_o = 1'b0; k1 = 8'd0;
				end
				cnt_o = k1;
				if (k1 < nb8) begin                           // 0x08019CE0-0x08019CEC, 0x08019D3A
					if (half != 11'd0) begin
						mix   = 1'b1;
						idx   = bidx(half, fill_o, k1);
						blk_o = blk + 12'd1;
					end
					cnt_o = k1 + 8'd1;
				end
			end
		end
	end

endmodule
