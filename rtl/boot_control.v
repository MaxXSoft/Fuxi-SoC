// EMIO GPIO 0 is low/input at reset. FSBL raises it after PS/QSPI setup.
module boot_control (
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *) input wire clk,
  input wire fabric_resetn, input wire run_o, input wire run_t,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 core_resetn RST",
     X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *) output wire core_resetn
);
  (* ASYNC_REG = "TRUE" *) reg [1:0] release_sync;
  wire hold_reset = !fabric_resetn || !run_o || run_t;
  always @(posedge clk or posedge hold_reset) begin
    if (hold_reset) release_sync <= 0;
    else release_sync <= {release_sync[0], 1'b1};
  end
  assign core_resetn = release_sync[1];
endmodule
