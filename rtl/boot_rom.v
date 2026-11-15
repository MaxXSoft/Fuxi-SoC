// Inferred single-port block ROM behind AMD's AXI BRAM Controller.
// The controller supplies byte addresses and a one-cycle native read interface.

module boot_rom #(
  parameter INIT_FILE = "bootrom.mem"
) (
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM CLK",
     X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ_WRITE, MEM_SIZE 16384, MEM_WIDTH 32, MEM_ECC NONE, READ_LATENCY 1" *) input wire clk,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM RST" *) input wire rst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM EN" *) input wire en,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM ADDR" *) input wire [13:0] addr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM DIN" *) input wire [31:0] din,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM WE" *) input wire [3:0] we,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM DOUT" *) output reg [31:0] dout
);

  (* rom_style = "block" *) reg [31:0] words [0:4095];
  initial $readmemh(INIT_FILE, words);
  always @(posedge clk) if (en) dout <= words[addr[13:2]];
  // Writes intentionally have no effect; ROM contents change with the bitstream.

endmodule
