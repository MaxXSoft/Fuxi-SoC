`timescale 1ns/1ps
module peripherals_tb;
  reg clk=0;
  always #10 clk=~clk;
  reg resetn=0;
  wire irq_soft, irq_timer, irq_m, irq_s;
  wire [63:0] rtc_time;
  reg [31:1] sources=0;
  reg [15:0] c_awaddr=0;
  reg c_awvalid=0;
  wire c_awready;
  reg [31:0] c_wdata=0;
  reg [3:0] c_wstrb=0;
  reg c_wvalid=0;
  wire c_wready;
  wire [1:0] c_bresp;
  wire c_bvalid;
  reg c_bready=0;
  reg [15:0] c_araddr=0;
  reg c_arvalid=0;
  wire c_arready;
  wire [31:0] c_rdata;
  wire [1:0] c_rresp;
  wire c_rvalid;
  reg c_rready=0;
  clint dut_c (.clk(clk), .resetn(resetn),
    .s_axi_awaddr(c_awaddr),
    .s_axi_awvalid(c_awvalid),
    .s_axi_awready(c_awready),
    .s_axi_wdata(c_wdata),
    .s_axi_wstrb(c_wstrb),
    .s_axi_wvalid(c_wvalid),
    .s_axi_wready(c_wready),
    .s_axi_bresp(c_bresp),
    .s_axi_bvalid(c_bvalid),
    .s_axi_bready(c_bready),
    .s_axi_araddr(c_araddr),
    .s_axi_arvalid(c_arvalid),
    .s_axi_arready(c_arready),
    .s_axi_rdata(c_rdata),
    .s_axi_rresp(c_rresp),
    .s_axi_rvalid(c_rvalid),
    .s_axi_rready(c_rready),
    .irq_soft(irq_soft), .irq_timer(irq_timer), .rtc_time(rtc_time));
  task automatic c_write(input [21:0] addr, input [31:0] data, input [3:0] strb=15, input integer aw_delay=0, input integer w_delay=0);
    fork
      begin
        repeat(aw_delay) @(negedge clk);
        @(negedge clk); c_awaddr=addr[15:0]; c_awvalid=1;
        do @(posedge clk); while (!c_awready);
        @(negedge clk); c_awvalid=0;
      end
      begin
        repeat(w_delay) @(negedge clk);
        @(negedge clk); c_wdata=data; c_wstrb=strb; c_wvalid=1;
        do @(posedge clk); while (!c_wready);
        @(negedge clk); c_wvalid=0;
      end
    join
    wait (c_bvalid);
    repeat(3) begin @(negedge clk); if (!c_bvalid || c_bresp != 0) $fatal(1,"B backpressure"); end
    c_bready=1;
    @(negedge clk); c_bready=0;
  endtask
  task automatic c_read(input [21:0] addr, output [31:0] data);
    @(negedge clk); c_araddr=addr[15:0]; c_arvalid=1;
    do @(posedge clk); while (!c_arready);
    @(negedge clk); c_arvalid=0;
    wait (c_rvalid); data=c_rdata;
    repeat(4) begin @(negedge clk); if (!c_rvalid || c_rdata != data || c_rresp != 0) $fatal(1,"R backpressure"); end
    c_rready=1;
    @(negedge clk); c_rready=0;
  endtask
  reg [21:0] p_awaddr=0;
  reg p_awvalid=0;
  wire p_awready;
  reg [31:0] p_wdata=0;
  reg [3:0] p_wstrb=0;
  reg p_wvalid=0;
  wire p_wready;
  wire [1:0] p_bresp;
  wire p_bvalid;
  reg p_bready=0;
  reg [21:0] p_araddr=0;
  reg p_arvalid=0;
  wire p_arready;
  wire [31:0] p_rdata;
  wire [1:0] p_rresp;
  wire p_rvalid;
  reg p_rready=0;
  plic dut_p (.clk(clk), .resetn(resetn),
    .s_axi_awaddr(p_awaddr),
    .s_axi_awvalid(p_awvalid),
    .s_axi_awready(p_awready),
    .s_axi_wdata(p_wdata),
    .s_axi_wstrb(p_wstrb),
    .s_axi_wvalid(p_wvalid),
    .s_axi_wready(p_wready),
    .s_axi_bresp(p_bresp),
    .s_axi_bvalid(p_bvalid),
    .s_axi_bready(p_bready),
    .s_axi_araddr(p_araddr),
    .s_axi_arvalid(p_arvalid),
    .s_axi_arready(p_arready),
    .s_axi_rdata(p_rdata),
    .s_axi_rresp(p_rresp),
    .s_axi_rvalid(p_rvalid),
    .s_axi_rready(p_rready),
    .sources(sources), .irq_m(irq_m), .irq_s(irq_s));
  task automatic p_write(input [21:0] addr, input [31:0] data, input [3:0] strb=15, input integer aw_delay=0, input integer w_delay=0);
    fork
      begin
        repeat(aw_delay) @(negedge clk);
        @(negedge clk); p_awaddr=addr; p_awvalid=1;
        do @(posedge clk); while (!p_awready);
        @(negedge clk); p_awvalid=0;
      end
      begin
        repeat(w_delay) @(negedge clk);
        @(negedge clk); p_wdata=data; p_wstrb=strb; p_wvalid=1;
        do @(posedge clk); while (!p_wready);
        @(negedge clk); p_wvalid=0;
      end
    join
    wait (p_bvalid);
    repeat(3) begin @(negedge clk); if (!p_bvalid || p_bresp != 0) $fatal(1,"B backpressure"); end
    p_bready=1;
    @(negedge clk); p_bready=0;
  endtask
  task automatic p_read(input [21:0] addr, output [31:0] data);
    @(negedge clk); p_araddr=addr; p_arvalid=1;
    do @(posedge clk); while (!p_arready);
    @(negedge clk); p_arvalid=0;
    wait (p_rvalid); data=p_rdata;
    repeat(4) begin @(negedge clk); if (!p_rvalid || p_rdata != data || p_rresp != 0) $fatal(1,"R backpressure"); end
    p_rready=1;
    @(negedge clk); p_rready=0;
  endtask
  reg [31:0] v;
  integer source_id, expected_priority;
  initial begin
    #200000; $fatal(1,"timeout");
  end
  initial begin
    repeat(5) @(negedge clk); resetn=1;
    if (irq_soft || irq_timer || irq_m || irq_s) $fatal(1,"reset IRQ");
    c_write('h0,1,1,0,4); if (!irq_soft) $fatal(1,"msip set");
    c_write('h0,0,2,4,0); if (!irq_soft) $fatal(1,"msip byte mask");
    c_read('h0,v); if(v!=1) $fatal(1,"msip read");
    c_write('h0,0); if(irq_soft) $fatal(1,"msip clear");
    c_write('h4000,'h12345678,15,3,0);
    c_write('h4000,'habcdef00,2,0,3);
    c_read('h4000,v); if(v!='h1234ef78) $fatal(1,"mtimecmp strobes");
    c_write('h4000,1); c_write('h4004,0);
    if(!irq_timer) $fatal(1,"timer expiry");
    c_write('h4004,'hffffffff); if(irq_timer) $fatal(1,"timer deassert");
    c_write('hbffc,7); c_read('hbffc,v); if(v!=7) $fatal(1,"mtime high writable");
    c_read('h4008,v); if(v != 0) $fatal(1,"CLINT reserved");
    // IDs 2 and 10 at equal priority: lower ID wins. M and S compete globally.
    p_write(8,3,15,0,4); p_write(40,3,15,4,0);
    p_write('h2000,'h404); p_write('h2080,'h404);
    @(negedge clk); sources[2]=1; sources[10]=1;
    repeat(5) @(negedge clk);
    if(!irq_m || !irq_s) $fatal(1,"PLIC delivery");
    p_read('h200004,v); if(v!=2) $fatal(1,"PLIC tie arbitration");
    p_read('h201004,v); if(v!=10) $fatal(1,"PLIC atomic claim");
    p_read('h200004,v); if(v != 0) $fatal(1,"gateway busy until completion");
    p_write('h201004,10,3); // partial completion must not release gateway
    p_read('h200004,v); if(v != 0) $fatal(1,"partial completion");
    p_write('h201004,10); repeat(5) @(negedge clk);
    if(!irq_m || !irq_s) $fatal(1,"level retrigger");
    p_write('h200000,7); if(irq_m || !irq_s) $fatal(1,"context threshold");
    p_read('h200004,v); if(v!=10) $fatal(1,"claim ignores threshold");
    @(negedge clk); sources=0;
    repeat(4) @(negedge clk);
    p_write('h200004,10); p_write('h200004,2);
    p_read('h1000,v); if(v != 0) $fatal(1,"pending clear");
    p_write(0,7); p_read(0,v); if(v != 0) $fatal(1,"source zero reserved");
    p_write('h2080,'hffffffff); p_read('h2080,v); if(v!='hfffffffe) $fatal(1,"enable WARL");
    // All leaves of the arbitration tree, descending priorities then ascending IDs.
    p_write('h2000,'hfffffffe); p_write('h2080,0); p_write('h200000,0);
    for (source_id=1; source_id<32; source_id=source_id+1)
      p_write(22'(source_id*4), 32'(source_id%7+1));
    @(negedge clk); sources='1;
    repeat(5) @(negedge clk);
    for (expected_priority=7; expected_priority>0; expected_priority=expected_priority-1)
      for (source_id=1; source_id<32; source_id=source_id+1)
        if (source_id%7+1 == expected_priority) begin
          p_read('h200004,v);
          if(v != 32'(source_id)) $fatal(1,"full PLIC priority ordering");
        end
    p_read('h200004,v); if(v != 0) $fatal(1,"no duplicate claims");
    $display("PASS: CLINT, PLIC, independent AW/W, response backpressure");
    $finish;
  end
endmodule
