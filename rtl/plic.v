// Standard single-hart platform peripheral; addresses are relative to the AXI segment.
module plic (
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK",
     X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET resetn" *)
  input wire clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST",
     X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input wire resetn,
  input wire [31:1] sources, output reg irq_m, output reg irq_s,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
  input wire [21:0] s_axi_awaddr,
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
  input wire [21:0] s_axi_araddr,
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
  wire [21:0] wr_addr, rd_addr;
  wire [31:0] wr_data;
  wire [3:0] wr_strb;
  reg [31:0] rd_data;
  axi_lite_regs #(.ADDR_WIDTH(22)) bus (
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

  // Level-sensitive gateways. A source cannot pend again until completion.
  (* ASYNC_REG = "TRUE" *) reg [31:1] sync1, sync2;
  reg [31:1] pending, busy;
  reg [31:1] enables [0:1];
  reg [2:0] priority_reg [1:31];
  reg [2:0] threshold [0:1];
  reg [4:0] winner [0:1];
  reg [2:0] best [0:1];
  reg [4:0] tree_id [0:1][1:63];
  reg [2:0] tree_pri [0:1][1:63];
  integer c, i;
  // Balanced tournament: five comparator levels, independent of source count
  // within this 32-leaf tree. Equal priorities choose the lower source ID.
  // Claim ignores threshold, as required by the PLIC specification.
  always @* begin
    for (c=0; c<2; c=c+1) begin
      tree_pri[c][32] = 0; tree_id[c][32] = 0;
      for (i=1; i<32; i=i+1) begin
        tree_pri[c][32+i] = (pending[i] && enables[c][i]) ? priority_reg[i] : 3'b0;
        tree_id[c][32+i] = i[4:0];
      end
      for (i=31; i>0; i=i-1) begin
        if (tree_pri[c][2*i] >= tree_pri[c][2*i+1]) begin
          tree_pri[c][i] = tree_pri[c][2*i]; tree_id[c][i] = tree_id[c][2*i];
        end else begin
          tree_pri[c][i] = tree_pri[c][2*i+1]; tree_id[c][i] = tree_id[c][2*i+1];
        end
      end
      best[c] = tree_pri[c][1];
      winner[c] = (best[c] == 0) ? 5'b0 : tree_id[c][1];
    end
  end
  // PLIC notification may lag register/gateway changes by one cycle. Keeping
  // the CPU-facing interrupt registered avoids a combinational path through
  // arbitration and the core's trap/flush selection in the same cycle.
  always @(posedge clk) begin
    if (!resetn) begin irq_m <= 0; irq_s <= 0; end
    else begin irq_m <= best[0] > threshold[0]; irq_s <= best[1] > threshold[1]; end
  end
  wire claim_m = rd_en && rd_addr == 22'h200004;
  wire claim_s = rd_en && rd_addr == 22'h201004;
  integer j, b;
  always @(posedge clk) begin
    if (!resetn) begin
      sync1 <= 0; sync2 <= 0; pending <= 0; busy <= 0;
      enables[0] <= 0; enables[1] <= 0;
      threshold[0] <= 0; threshold[1] <= 0;
      for (j=1; j<32; j=j+1) priority_reg[j] <= 0;
    end else begin
      sync1 <= sources; sync2 <= sync1;
      for (j=1; j<32; j=j+1) begin
        if (sync2[j] && !busy[j]) begin pending[j] <= 1; busy[j] <= 1; end
        if ((claim_m && winner[0] == j[4:0]) || (claim_s && winner[1] == j[4:0])) pending[j] <= 0;
        // Completion only from an enabled context; source 0 and invalid IDs ignored.
        if (wr_en && wr_strb == 4'hf && wr_data == j &&
            ((wr_addr == 22'h200004 && enables[0][j]) ||
             (wr_addr == 22'h201004 && enables[1][j])) && !pending[j]) busy[j] <= 0;
        if (wr_en && wr_addr == {15'b0, j[4:0], 2'b0} && wr_strb[0]) priority_reg[j] <= wr_data[2:0];
      end
      if (wr_en) begin
        for (b=0; b<4; b=b+1) if (wr_strb[b]) begin
          for (j=1; j<32; j=j+1) if (j/8 == b) begin
            if (wr_addr == 22'h002000) enables[0][j] <= wr_data[j];
            if (wr_addr == 22'h002080) enables[1][j] <= wr_data[j];
          end
        end
        if (wr_strb[0]) begin
          if (wr_addr == 22'h200000) threshold[0] <= wr_data[2:0];
          if (wr_addr == 22'h201000) threshold[1] <= wr_data[2:0];
        end
      end
    end
  end
  integer k;
  always @* begin
    rd_data = 0;
    for (k=1; k<32; k=k+1) if (rd_addr == {15'b0, k[4:0], 2'b0}) rd_data = {29'b0, priority_reg[k]};
    case (rd_addr)
      22'h001000: rd_data = {pending, 1'b0};
      22'h002000: rd_data = {enables[0], 1'b0};
      22'h002080: rd_data = {enables[1], 1'b0};
      22'h200000: rd_data = {29'b0, threshold[0]};
      22'h201000: rd_data = {29'b0, threshold[1]};
      22'h200004: rd_data = {27'b0, winner[0]};
      22'h201004: rd_data = {27'b0, winner[1]};
      default: ;
    endcase
  end
endmodule
