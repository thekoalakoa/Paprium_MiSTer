derive_pll_clocks
derive_clock_uncertainty

# core specific constraints
#set_multicycle_path -from {emu|md_board|*} -to {emu|cartridge|*} -setup 2
#set_multicycle_path -from {emu|md_board|*} -to {emu|cartridge|*} -hold 1

# 0.2.6: the option-D values the
# MCU writes into paprium_xlink (clk_sys) reach paprium_mcd_link (clk_md) without a synchroniser of their own;
# mcd_link copies them only on the clock its synchronised ARM toggle moves (>= 3 clk_md clocks after the MCU's
# ARM write, which follows the value writes) and reads HOLD / the enable as settings written long before a post.
set od_vals [get_registers {*|paprium_xlink:*|d_word[*] *|paprium_xlink:*|d_busy[*] *|paprium_xlink:*|pend[*] *|paprium_xlink:*|od_hold[*] *|paprium_xlink:*|od_en}]
set od_caps [get_registers {*|paprium_mcd_link:*}]
if {[get_collection_size $od_vals] == 0 || [get_collection_size $od_caps] == 0} {
  post_message -type critical_warning "0.2.6: buddy option-D multicycle matched nothing"
} else {
  set_multicycle_path -end -setup -from $od_vals -to $od_caps 2
  set_multicycle_path -end -hold  -from $od_vals -to $od_caps 2
}

# 0.3.0: the boot stub's GO (clk_sys, a power-on flag set once) reaches the reset envelope
# on clk_md through synch_3 fw_go_sync; the first stage is a plain clock crossing.
set_false_path -to [get_registers {*|synch_3:fw_go_sync|stage_1*}]
# 0.3.0: Console Reset toggles / CAUSE.V and the BAR value into the video clock cross through synch_3 too.
set_false_path -to [get_registers {*|synch_3:cr_req_sync|stage_1*}]
set_false_path -to [get_registers {*|synch_3:cr_v_sync|stage_1*}]
set_false_path -to [get_registers {*|synch_3:cr_acc_sync|stage_1*}]
set_false_path -to [get_registers {*|synch_3:bar_sync|stage_1*}]

# 0.3.0 pass 2: SP - stream pointer. ONLY with the SP-X RTL (cartridge.sv generate block stream_x);
# without it this path is a real race and must stay timed. On shared edges rom_addr and stream_x held take held,
# never the live stream_addr (stream_x shared_next is a clk_md function of ph -> ph_f, taken on the falling clk_md
# edge with 4.66 ns of setup and hold, which stays timed).
# Ported from Pocket paprium-pocket target/pocket/core_constraints.sdc (69f9f6f / B Jam PC), hold-only.
# No xf_col helper on MiSTer — empty-collection guard inlined. Do not widen to a setup false-path.
# Cart instance names: cartridge:cartridge, paprium_cart:paprium (MegaDrive.sv / cartridge.sv).
if {[get_collection_size [get_registers -nowarn {*|cartridge:cartridge|stream_x*held*}]] > 0} {
  set sp_src [get_registers -nowarn {*|paprium_cart:paprium|stream_ptr*}]
  if {[get_collection_size $sp_src] == 0} {
    post_message -type warning "xfix SP: stream_ptr matched nothing"
  } else {
    set_false_path -hold -from $sp_src \
                         -to   [get_registers {*|cartridge:cartridge|rom_addr* *|cartridge:cartridge|stream_x*held*}]
  }
}
