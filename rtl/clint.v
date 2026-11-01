// Standard single-hart platform peripheral; addresses are relative to the AXI segment.
module clint (
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK",
     X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET resetn" *)
  input wire clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST",
     X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input wire resetn,
  output wire irq_soft, output reg irq_timer, output reg [63:0] rtc_time,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
  input wire [15:0] s_axi_awaddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
  input wire s_axi_awvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
  output wire s_axi_awready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
  input wire [31:0] s_axi_wdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
  input wire [3:0] s_axi_wstrb,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
  input wire s_axi_wvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
  output wire s_axi_wready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
  output wire [1:0] s_axi_bresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
  output wire s_axi_bvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
  input wire s_axi_bready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
  input wire [15:0] s_axi_araddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
  input wire s_axi_arvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
  output wire s_axi_arready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
  output wire [31:0] s_axi_rdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
  output wire [1:0] s_axi_rresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
  output wire s_axi_rvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
  input wire s_axi_rready
);
  wire wr_en, rd_en;
  wire [15:0] wr_addr, rd_addr;
  wire [31:0] wr_data;
  wire [3:0] wr_strb;
  reg [31:0] rd_data;
  axi_lite_regs #(.ADDR_WIDTH(16)) bus (
    .clk(clk), .resetn(resetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data), .wr_strb(wr_strb),
    .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data)
  );

  reg msip;
  reg [63:0] mtimecmp;
  assign irq_soft = msip;
  // The timer interrupt reflects mtime/mtimecmp with one cycle of latency.
  // This also keeps its comparator out of the CPU's trap-selection path.
  always @(posedge clk) begin
    if (!resetn) irq_timer <= 0;
    else irq_timer <= rtc_time >= mtimecmp;
  end
  integer b;
  always @(posedge clk) begin
    if (!resetn) begin
      msip <= 0; rtc_time <= 0; mtimecmp <= 64'hffffffffffffffff;
    end else begin
      rtc_time <= rtc_time + 1'b1;
      if (wr_en) begin
        if (wr_addr == 16'h0000 && wr_strb[0]) msip <= wr_data[0];
        for (b=0; b<4; b=b+1) if (wr_strb[b]) begin
          case (wr_addr)
            16'h4000: mtimecmp[b*8 +: 8] <= wr_data[b*8 +: 8];
            16'h4004: mtimecmp[32+b*8 +: 8] <= wr_data[b*8 +: 8];
            16'hbff8: rtc_time[b*8 +: 8] <= wr_data[b*8 +: 8];
            16'hbffc: rtc_time[32+b*8 +: 8] <= wr_data[b*8 +: 8];
            default: ;
          endcase
        end
      end
    end
  end
  always @* begin
    rd_data = 0;
    case (rd_addr)
      16'h0000: rd_data = {31'b0, msip};
      16'h4000: rd_data = mtimecmp[31:0];
      16'h4004: rd_data = mtimecmp[63:32];
      16'hbff8: rd_data = rtc_time[31:0];
      16'hbffc: rd_data = rtc_time[63:32];
      default: ;
    endcase
  end
endmodule
