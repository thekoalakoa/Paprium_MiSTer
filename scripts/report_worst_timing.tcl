project_open MegaDrive -revision MegaDrive
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_timing -setup -npaths 10 -detail full_path -stdout
project_close
