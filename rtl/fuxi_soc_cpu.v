// Address translation is after Fuxi's cacheability decision.

module fuxi_soc_cpu (
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK",
     X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF INST:DATA:UNCACHED, ASSOCIATED_RESET resetn" *)
  input wire clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST",
     X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input wire resetn,
  input wire irq_timer, irq_soft, irq_m, irq_s,
  input wire [63:0] rtc_time,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARREADY" *)
  input wire  inst_arready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARVALID" *)
  output wire  inst_arvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARADDR" *)
  output wire [31:0] inst_araddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARID" *)
  output wire [3:0] inst_arid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARSIZE" *)
  output wire [2:0] inst_arsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARLEN" *)
  output wire [7:0] inst_arlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARBURST" *)
  output wire [1:0] inst_arburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARLOCK" *)
  output wire  inst_arlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARCACHE" *)
  output wire [3:0] inst_arcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST ARPROT" *)
  output wire [2:0] inst_arprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RREADY" *)
  output wire  inst_rready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RVALID" *)
  input wire  inst_rvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RDATA" *)
  input wire [31:0] inst_rdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RID" *)
  input wire [3:0] inst_rid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RLAST" *)
  input wire  inst_rlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST RRESP" *)
  input wire [1:0] inst_rresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWREADY" *)
  input wire  inst_awready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWVALID" *)
  output wire  inst_awvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWADDR" *)
  output wire [31:0] inst_awaddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWID" *)
  output wire [3:0] inst_awid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWSIZE" *)
  output wire [2:0] inst_awsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWLEN" *)
  output wire [7:0] inst_awlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWBURST" *)
  output wire [1:0] inst_awburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWLOCK" *)
  output wire  inst_awlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWCACHE" *)
  output wire [3:0] inst_awcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST AWPROT" *)
  output wire [2:0] inst_awprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST WREADY" *)
  input wire  inst_wready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST WVALID" *)
  output wire  inst_wvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST WDATA" *)
  output wire [31:0] inst_wdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST WLAST" *)
  output wire  inst_wlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST WSTRB" *)
  output wire [3:0] inst_wstrb,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST BREADY" *)
  output wire  inst_bready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST BVALID" *)
  input wire  inst_bvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST BID" *)
  input wire [3:0] inst_bid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 INST BRESP" *)
  input wire [1:0] inst_bresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARREADY" *)
  input wire  data_arready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARVALID" *)
  output wire  data_arvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARADDR" *)
  output wire [31:0] data_araddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARID" *)
  output wire [3:0] data_arid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARSIZE" *)
  output wire [2:0] data_arsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARLEN" *)
  output wire [7:0] data_arlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARBURST" *)
  output wire [1:0] data_arburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARLOCK" *)
  output wire  data_arlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARCACHE" *)
  output wire [3:0] data_arcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA ARPROT" *)
  output wire [2:0] data_arprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RREADY" *)
  output wire  data_rready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RVALID" *)
  input wire  data_rvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RDATA" *)
  input wire [31:0] data_rdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RID" *)
  input wire [3:0] data_rid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RLAST" *)
  input wire  data_rlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA RRESP" *)
  input wire [1:0] data_rresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWREADY" *)
  input wire  data_awready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWVALID" *)
  output wire  data_awvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWADDR" *)
  output wire [31:0] data_awaddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWID" *)
  output wire [3:0] data_awid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWSIZE" *)
  output wire [2:0] data_awsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWLEN" *)
  output wire [7:0] data_awlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWBURST" *)
  output wire [1:0] data_awburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWLOCK" *)
  output wire  data_awlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWCACHE" *)
  output wire [3:0] data_awcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA AWPROT" *)
  output wire [2:0] data_awprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA WREADY" *)
  input wire  data_wready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA WVALID" *)
  output wire  data_wvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA WDATA" *)
  output wire [31:0] data_wdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA WLAST" *)
  output wire  data_wlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA WSTRB" *)
  output wire [3:0] data_wstrb,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA BREADY" *)
  output wire  data_bready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA BVALID" *)
  input wire  data_bvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA BID" *)
  input wire [3:0] data_bid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 DATA BRESP" *)
  input wire [1:0] data_bresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARREADY" *)
  input wire  uncached_arready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARVALID" *)
  output wire  uncached_arvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARADDR" *)
  output wire [31:0] uncached_araddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARID" *)
  output wire [3:0] uncached_arid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARSIZE" *)
  output wire [2:0] uncached_arsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARLEN" *)
  output wire [7:0] uncached_arlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARBURST" *)
  output wire [1:0] uncached_arburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARLOCK" *)
  output wire  uncached_arlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARCACHE" *)
  output wire [3:0] uncached_arcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED ARPROT" *)
  output wire [2:0] uncached_arprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RREADY" *)
  output wire  uncached_rready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RVALID" *)
  input wire  uncached_rvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RDATA" *)
  input wire [31:0] uncached_rdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RID" *)
  input wire [3:0] uncached_rid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RLAST" *)
  input wire  uncached_rlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED RRESP" *)
  input wire [1:0] uncached_rresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWREADY" *)
  input wire  uncached_awready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWVALID" *)
  output wire  uncached_awvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWADDR" *)
  output wire [31:0] uncached_awaddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWID" *)
  output wire [3:0] uncached_awid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWSIZE" *)
  output wire [2:0] uncached_awsize,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWLEN" *)
  output wire [7:0] uncached_awlen,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWBURST" *)
  output wire [1:0] uncached_awburst,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWLOCK" *)
  output wire  uncached_awlock,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWCACHE" *)
  output wire [3:0] uncached_awcache,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED AWPROT" *)
  output wire [2:0] uncached_awprot,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED WREADY" *)
  input wire  uncached_wready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED WVALID" *)
  output wire  uncached_wvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED WDATA" *)
  output wire [31:0] uncached_wdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED WLAST" *)
  output wire  uncached_wlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED WSTRB" *)
  output wire [3:0] uncached_wstrb,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED BREADY" *)
  output wire  uncached_bready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED BVALID" *)
  input wire  uncached_bvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED BID" *)
  input wire [3:0] uncached_bid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 UNCACHED BRESP" *)
  input wire [1:0] uncached_bresp
);

  function [31:0] translate;
    input [31:0] addr;
    begin
      if (addr[31:27] == 5'b10000) translate = {5'b00001, addr[26:0]}; // DDR: 0x80000000 -> 0x08000000
      else if (addr[31:12] == 20'h10000) translate = {20'he0001, addr[11:0]}; // UART1
      else if (addr[31:24] == 8'h18) translate = {8'hfc, addr[23:0]}; // QSPI bank 0
      else translate = addr;
    end
  endfunction

  wire [31:0] core_inst_araddr;
  assign inst_araddr = translate(core_inst_araddr);

  wire [31:0] core_inst_awaddr;
  assign inst_awaddr = translate(core_inst_awaddr);

  wire [31:0] core_data_araddr;
  assign data_araddr = translate(core_data_araddr);

  wire [31:0] core_data_awaddr;
  assign data_awaddr = translate(core_data_awaddr);

  wire [31:0] core_uncached_araddr;
  assign uncached_araddr = translate(core_uncached_araddr);

  wire [31:0] core_uncached_awaddr;
  assign uncached_awaddr = translate(core_uncached_awaddr);

  FuxiWrapper cpu (
    .clk(clk), .rst(!resetn),

    .irq_timer(irq_timer), .irq_soft(irq_soft),
    .irq_extern(irq_m), .irq_sextern(irq_s),
    .rtc_time(rtc_time),

    .debug_wen(),
    .debug_waddr(),
    .debug_wdata(),
    .debug_pc(),

    .inst_arready(inst_arready),
    .inst_arvalid(inst_arvalid),
    .inst_araddr(core_inst_araddr),
    .inst_arid(inst_arid),
    .inst_arsize(inst_arsize),
    .inst_arlen(inst_arlen),
    .inst_arburst(inst_arburst),
    .inst_arlock(inst_arlock),
    .inst_arcache(inst_arcache),
    .inst_arprot(inst_arprot),
    .inst_rready(inst_rready),
    .inst_rvalid(inst_rvalid),
    .inst_rdata(inst_rdata),
    .inst_rid(inst_rid),
    .inst_rlast(inst_rlast),
    .inst_rresp(inst_rresp),
    .inst_awready(inst_awready),
    .inst_awvalid(inst_awvalid),
    .inst_awaddr(core_inst_awaddr),
    .inst_awid(inst_awid),
    .inst_awsize(inst_awsize),
    .inst_awlen(inst_awlen),
    .inst_awburst(inst_awburst),
    .inst_awlock(inst_awlock),
    .inst_awcache(inst_awcache),
    .inst_awprot(inst_awprot),
    .inst_wready(inst_wready),
    .inst_wvalid(inst_wvalid),
    .inst_wdata(inst_wdata),
    .inst_wid(),
    .inst_wlast(inst_wlast),
    .inst_wstrb(inst_wstrb),
    .inst_bready(inst_bready),
    .inst_bvalid(inst_bvalid),
    .inst_bid(inst_bid),
    .inst_bresp(inst_bresp),
    .data_arready(data_arready),
    .data_arvalid(data_arvalid),
    .data_araddr(core_data_araddr),
    .data_arid(data_arid),
    .data_arsize(data_arsize),
    .data_arlen(data_arlen),
    .data_arburst(data_arburst),
    .data_arlock(data_arlock),
    .data_arcache(data_arcache),
    .data_arprot(data_arprot),
    .data_rready(data_rready),
    .data_rvalid(data_rvalid),
    .data_rdata(data_rdata),
    .data_rid(data_rid),
    .data_rlast(data_rlast),
    .data_rresp(data_rresp),
    .data_awready(data_awready),
    .data_awvalid(data_awvalid),
    .data_awaddr(core_data_awaddr),
    .data_awid(data_awid),
    .data_awsize(data_awsize),
    .data_awlen(data_awlen),
    .data_awburst(data_awburst),
    .data_awlock(data_awlock),
    .data_awcache(data_awcache),
    .data_awprot(data_awprot),
    .data_wready(data_wready),
    .data_wvalid(data_wvalid),
    .data_wdata(data_wdata),
    .data_wid(),
    .data_wlast(data_wlast),
    .data_wstrb(data_wstrb),
    .data_bready(data_bready),
    .data_bvalid(data_bvalid),
    .data_bid(data_bid),
    .data_bresp(data_bresp),
    .uncached_arready(uncached_arready),
    .uncached_arvalid(uncached_arvalid),
    .uncached_araddr(core_uncached_araddr),
    .uncached_arid(uncached_arid),
    .uncached_arsize(uncached_arsize),
    .uncached_arlen(uncached_arlen),
    .uncached_arburst(uncached_arburst),
    .uncached_arlock(uncached_arlock),
    .uncached_arcache(uncached_arcache),
    .uncached_arprot(uncached_arprot),
    .uncached_rready(uncached_rready),
    .uncached_rvalid(uncached_rvalid),
    .uncached_rdata(uncached_rdata),
    .uncached_rid(uncached_rid),
    .uncached_rlast(uncached_rlast),
    .uncached_rresp(uncached_rresp),
    .uncached_awready(uncached_awready),
    .uncached_awvalid(uncached_awvalid),
    .uncached_awaddr(core_uncached_awaddr),
    .uncached_awid(uncached_awid),
    .uncached_awsize(uncached_awsize),
    .uncached_awlen(uncached_awlen),
    .uncached_awburst(uncached_awburst),
    .uncached_awlock(uncached_awlock),
    .uncached_awcache(uncached_awcache),
    .uncached_awprot(uncached_awprot),
    .uncached_wready(uncached_wready),
    .uncached_wvalid(uncached_wvalid),
    .uncached_wdata(uncached_wdata),
    .uncached_wid(),
    .uncached_wlast(uncached_wlast),
    .uncached_wstrb(uncached_wstrb),
    .uncached_bready(uncached_bready),
    .uncached_bvalid(uncached_bvalid),
    .uncached_bid(uncached_bid),
    .uncached_bresp(uncached_bresp)
  );

endmodule
