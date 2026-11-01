// One outstanding transaction per direction; AW and W are independently buffered.
module axi_lite_regs #(parameter ADDR_WIDTH = 16) (
  input wire clk, input wire resetn,
  input wire [ADDR_WIDTH-1:0] s_axi_awaddr,
  input wire s_axi_awvalid, output wire s_axi_awready,
  input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
  input wire s_axi_wvalid, output wire s_axi_wready,
  output reg s_axi_bvalid, input wire s_axi_bready,
  output wire [1:0] s_axi_bresp,
  input wire [ADDR_WIDTH-1:0] s_axi_araddr,
  input wire s_axi_arvalid, output wire s_axi_arready,
  output reg [31:0] s_axi_rdata, output reg s_axi_rvalid,
  input wire s_axi_rready, output wire [1:0] s_axi_rresp,
  output wire wr_en, output reg [ADDR_WIDTH-1:0] wr_addr,
  output reg [31:0] wr_data, output reg [3:0] wr_strb,
  output wire rd_en, output wire [ADDR_WIDTH-1:0] rd_addr,
  input wire [31:0] rd_data
);
  reg aw_full, w_full;
  assign s_axi_awready = resetn && !aw_full && !s_axi_bvalid;
  assign s_axi_wready = resetn && !w_full && !s_axi_bvalid;
  assign s_axi_arready = resetn && !s_axi_rvalid;
  assign s_axi_bresp = 2'b00;
  assign s_axi_rresp = 2'b00;
  assign wr_en = aw_full && w_full && !s_axi_bvalid;
  assign rd_en = s_axi_arvalid && s_axi_arready;
  assign rd_addr = s_axi_araddr;
  always @(posedge clk) begin
    if (!resetn) begin
      aw_full <= 0; w_full <= 0;
      s_axi_bvalid <= 0; s_axi_rvalid <= 0;
      wr_addr <= 0; wr_data <= 0; wr_strb <= 0; s_axi_rdata <= 0;
    end else begin
      if (s_axi_awvalid && s_axi_awready) begin
        aw_full <= 1; wr_addr <= s_axi_awaddr;
      end
      if (s_axi_wvalid && s_axi_wready) begin
        w_full <= 1; wr_data <= s_axi_wdata; wr_strb <= s_axi_wstrb;
      end
      if (wr_en) begin
        aw_full <= 0; w_full <= 0; s_axi_bvalid <= 1;
      end else if (s_axi_bready) s_axi_bvalid <= 0;
      if (rd_en) begin
        s_axi_rdata <= rd_data; s_axi_rvalid <= 1;
      end else if (s_axi_rready) s_axi_rvalid <= 0;
    end
  end
endmodule
