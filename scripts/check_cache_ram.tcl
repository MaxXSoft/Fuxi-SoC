# Check the actual mapped primitives, rather than relying on the hint alone.
# Fail if a core/compiler hierarchy change makes the XDC stop selecting data RAM.
proc check_cache_ram {report_path} {
  set report [open $report_path w]
  foreach array {icache/lines_ext dcache/lines/mem_ext} {
    set brams [get_cells -quiet -hier -filter [format \
      {NAME =~ */%s/* && (REF_NAME == RAMB18E1 || REF_NAME == RAMB36E1)} $array]]
    set lutrams [get_cells -quiet -hier -filter [format \
      {NAME =~ */%s/* && REF_NAME =~ RAM* && REF_NAME !~ RAMB*} $array]]
    puts $report "$array: [llength $brams] BRAM primitives, [llength $lutrams] LUT RAM primitives"
    foreach ram $brams {
      puts $report "  [get_property REF_NAME $ram] $ram"
    }
    if {[llength $brams] == 0 || [llength $lutrams] != 0} {
      close $report
      error "Cache data array $array is not mapped exclusively to BRAM; see $report_path"
    }
  }
  close $report
}
