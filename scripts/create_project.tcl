# Run from any working directory: vivado -mode batch -source scripts/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build vivado]
create_project -force fuxi_zedboard $out -part xc7z020clg484-1
set_property board_part avnet.com:zedboard:part0:1.4 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files [glob $root/build/fuxi/*.v]
add_files $root/third_party/fuxi/verilog/FuxiWrapper.v
add_files [glob $root/rtl/*.v]
create_bd_design soc
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} [get_bd_cells ps7]
set_property -dict [list \
 CONFIG.PCW_USE_M_AXI_GP0 0 CONFIG.PCW_USE_S_AXI_GP0 1 \
 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 50 \
 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1 CONFIG.PCW_GPIO_EMIO_GPIO_IO 1 \
 CONFIG.PCW_USE_FABRIC_INTERRUPT 1 CONFIG.PCW_P2F_UART1_INTR 1 \
 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 0 CONFIG.PCW_USB0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 0 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 0] [get_bd_cells ps7]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 resets

# Board automation may create an EMIO GPIO top-level port; it is internal here.
foreach port [get_bd_intf_ports -quiet GPIO*] { delete_bd_objs $port }
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 core_resets
create_bd_cell -type module -reference boot_control boot
create_bd_cell -type module -reference fuxi_soc_cpu cpu
create_bd_cell -type module -reference clint clint_0
create_bd_cell -type module -reference plic plic_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero
set_property CONFIG.CONST_VAL 0 [get_bd_cells zero]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_sources
set_property -dict [list CONFIG.NUM_PORTS 3 CONFIG.IN0_WIDTH 9 CONFIG.IN1_WIDTH 1 CONFIG.IN2_WIDTH 21] [get_bd_cells irq_sources]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 irq_zero_low
set_property -dict [list CONFIG.CONST_VAL 0 CONFIG.CONST_WIDTH 9] [get_bd_cells irq_zero_low]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 irq_zero_high
set_property -dict [list CONFIG.CONST_VAL 0 CONFIG.CONST_WIDTH 21] [get_bd_cells irq_zero_high]
connect_bd_net [get_bd_pins irq_zero_low/dout] [get_bd_pins irq_sources/In0]
connect_bd_net [get_bd_pins ps7/IRQ_P2F_UART1] [get_bd_pins irq_sources/In1]
connect_bd_net [get_bd_pins irq_zero_high/dout] [get_bd_pins irq_sources/In2]
connect_bd_net [get_bd_pins irq_sources/dout] [get_bd_pins plic_0/sources]
connect_bd_net [get_bd_pins zero/dout] [get_bd_pins ps7/GPIO_I] [get_bd_pins resets/mb_debug_sys_rst] [get_bd_pins core_resets/mb_debug_sys_rst]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins resets/aux_reset_in] [get_bd_pins core_resets/aux_reset_in] [get_bd_pins resets/dcm_locked] [get_bd_pins core_resets/dcm_locked]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins resets/ext_reset_in]
connect_bd_net [get_bd_pins ps7/GPIO_O] [get_bd_pins boot/run_o]
connect_bd_net [get_bd_pins ps7/GPIO_T] [get_bd_pins boot/run_t]
connect_bd_net [get_bd_pins resets/peripheral_aresetn] [get_bd_pins boot/fabric_resetn]
connect_bd_net [get_bd_pins boot/core_resetn] [get_bd_pins core_resets/ext_reset_in]
connect_bd_net [get_bd_pins core_resets/peripheral_aresetn] [get_bd_pins cpu/resetn] [get_bd_pins clint_0/resetn] [get_bd_pins plic_0/resetn]
connect_bd_net [get_bd_pins clint_0/irq_soft] [get_bd_pins cpu/irq_soft]
connect_bd_net [get_bd_pins clint_0/irq_timer] [get_bd_pins cpu/irq_timer]
connect_bd_net [get_bd_pins clint_0/rtc_time] [get_bd_pins cpu/rtc_time]
connect_bd_net [get_bd_pins plic_0/irq_m] [get_bd_pins cpu/irq_m]
connect_bd_net [get_bd_pins plic_0/irq_s] [get_bd_pins cpu/irq_s]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi
set_property -dict [list CONFIG.NUM_SI 3 CONFIG.NUM_MI 4 \
 CONFIG.S00_HAS_REGSLICE 1 CONFIG.S01_HAS_REGSLICE 1 CONFIG.S02_HAS_REGSLICE 1 \
 CONFIG.M00_HAS_REGSLICE 1 CONFIG.M01_HAS_REGSLICE 1 CONFIG.M02_HAS_REGSLICE 1 CONFIG.M03_HAS_REGSLICE 1] [get_bd_cells axi]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 rom_ctrl
set_property -dict [list CONFIG.DATA_WIDTH 32 CONFIG.SINGLE_PORT_BRAM 1] [get_bd_cells rom_ctrl]
add_files $root/build/bootrom/bootrom.mem
set_property file_type {Memory Initialization Files} [get_files bootrom.mem]
create_bd_cell -type module -reference boot_rom rom
connect_bd_intf_net [get_bd_intf_pins rom_ctrl/BRAM_PORTA] [get_bd_intf_pins rom/BRAM]
foreach {cpu_port axi_port} {INST S00_AXI DATA S01_AXI UNCACHED S02_AXI} {
 connect_bd_intf_net [get_bd_intf_pins cpu/$cpu_port] [get_bd_intf_pins axi/$axi_port]
}
foreach {axi_port target} {M00_AXI ps7/S_AXI_GP0 M01_AXI rom_ctrl/S_AXI M02_AXI clint_0/S_AXI M03_AXI plic_0/S_AXI} {
 connect_bd_intf_net [get_bd_intf_pins axi/$axi_port] [get_bd_intf_pins $target]
}
foreach pin {cpu/clk boot/clk clint_0/clk plic_0/clk resets/slowest_sync_clk core_resets/slowest_sync_clk ps7/S_AXI_GP0_ACLK axi/ACLK axi/S00_ACLK axi/S01_ACLK axi/S02_ACLK axi/M00_ACLK axi/M01_ACLK axi/M02_ACLK axi/M03_ACLK rom_ctrl/s_axi_aclk} {
 connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins $pin]
}
foreach pin {axi/ARESETN axi/S00_ARESETN axi/S01_ARESETN axi/S02_ARESETN axi/M00_ARESETN axi/M01_ARESETN axi/M02_ARESETN axi/M03_ARESETN rom_ctrl/s_axi_aresetn} {
 connect_bd_net [get_bd_pins resets/peripheral_aresetn] [get_bd_pins $pin]
}
# Only these PS windows are accessible; do not auto-map the entire PS DDR range.
foreach space [get_bd_addr_spaces cpu/*] {
 assign_bd_address -target_address_space $space -offset 0x08000000 -range 0x08000000 [get_bd_addr_segs ps7/S_AXI_GP0/GP0_DDR_LOWOCM]
 assign_bd_address -target_address_space $space -offset 0xE0001000 -range 0x1000 [get_bd_addr_segs ps7/S_AXI_GP0/GP0_IOP]
 assign_bd_address -target_address_space $space -offset 0xFC000000 -range 0x01000000 [get_bd_addr_segs ps7/S_AXI_GP0/GP0_QSPI_LINEAR]
 assign_bd_address -target_address_space $space -offset 0x00000000 -range 0x4000 [get_bd_addr_segs rom_ctrl/S_AXI/Mem0]
 assign_bd_address -target_address_space $space -offset 0x11000000 -range 0x10000 [get_bd_addr_segs clint_0/S_AXI/*]
 assign_bd_address -target_address_space $space -offset 0x12000000 -range 0x400000 [get_bd_addr_segs plic_0/S_AXI/*]
}
validate_bd_design
foreach cell {resets core_resets} {
 if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells $cell]] != 0 || [get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells $cell]] != 0} {
  error "Reset polarity changed: both ext_reset_in and aux_reset_in must be active-low"
 }
}
save_bd_design
set bd [get_files $out/fuxi_zedboard.srcs/sources_1/bd/soc/soc.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files $wrapper
set_property top soc_wrapper [current_fileset]
puts [exec python3 $root/scripts/sanitize_vivado_headers.py $out]
update_compile_order -fileset sources_1
set_property top soc_wrapper [current_fileset]
# Export the exact PS initialization used by the generated hardware.
write_hw_platform -fixed -force -file $root/build/fuxi_zedboard.xsa
puts "Created source-built ZedBoard project at $out"
