set root [file normalize [file join [file dirname [info script]] ..]]
set reports $root/build/reports
source $root/scripts/check_cache_ram.tcl
file mkdir $reports
open_project $root/build/vivado/fuxi_zedboard.xpr
set_param general.maxThreads 8
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
check_cache_ram $reports/cache_ram_synth.rpt
report_utilization -hierarchical -file $reports/utilization_synth.rpt
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
check_cache_ram $reports/cache_ram.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file $reports/timing_summary.rpt
report_timing -delay_type max -max_paths 10 -path_type full_clock_expanded -file $reports/critical_paths.rpt
report_utilization -hierarchical -file $reports/utilization.rpt
report_drc -file $reports/drc.rpt
report_route_status -file $reports/route_status.rpt
report_clock_interaction -file $reports/clock_interaction.rpt
report_methodology -file $reports/methodology.rpt
write_hw_platform -fixed -include_bit -force -file $root/build/fuxi_zedboard.xsa
file copy -force $root/build/vivado/fuxi_zedboard.runs/impl_1/soc_wrapper.bit $root/build/fuxi_zedboard.bit
foreach property {STATS.WNS STATS.TNS STATS.WHS STATS.THS} {
 puts "$property = [get_property $property [get_runs impl_1]]"
}
