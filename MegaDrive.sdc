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
