`timescale 1ns/1ps
// 32-bit word writes/physical acknowledgements and aligned BL8 reads.
// Reuses frozen r20f masked-burst controller unchanged. No extra data FIFO.
// Fairness masks only UNACCEPTED reads after a bounded write-wait budget.
// Reset discards queued IO and MUST be coordinated with every transaction client.
// forwarded_clk: related50MHz SDRAM clock, phase must be physically constrained.
module station_sdram_backend #(
 parameter integer POWER_CYCLES=10000,REFRESH_CYCLES=150,
 parameter integer MAX_PENDING_WRITES=32,WRITE_WAIT_CYCLES=64
)(
 input wire clk,forwarded_clk,arst_n,output wire initialized,
 input wire wr_valid,output wire wr_ready,input wire [20:0] wr_address,input wire [31:0] wr_data,
 output wire wr_rsp_valid,input wire wr_rsp_ready,output wire wr_rsp_error,
 input wire rd_valid,output wire rd_ready,input wire [20:0] rd_address,
 output wire rd_data_valid,output wire [31:0] rd_data,output wire rd_last,
 output wire quiet,output reg fault,
 output reg [31:0] write_acks,read_bursts,refresh_count,
 output wire sdram_clk,output wire sdram_ras_n,sdram_cas_n,sdram_we_n,
 output wire [10:0] sdram_addr,output wire [1:0] sdram_ba,
 output wire [3:0] sdram_dqm,inout wire [31:0] sdram_dq
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam CW=bits_for(MAX_PENDING_WRITES+1),TW=bits_for(WRITE_WAIT_CYCLES+1);
 wire rst_n;reset_sync resetter(.clk(clk),.arst_n(arst_n),.rst_n(rst_n));
 reg [CW-1:0] pending;reg [TW-1:0] write_age;reg read_active;reg [2:0] read_beat;
 wire raw_wr_ready,raw_rsp_valid,raw_rsp_error,raw_rd_ready,raw_rd_valid,raw_protocol_error;
 wire raw_data_valid,raw_last;wire [31:0] raw_data;wire unused_inverted_clock;
 wire write_force=pending!=0&&write_age>=WRITE_WAIT_CYCLES&&!raw_rsp_valid;
 wire read_allow=!fault&&!read_active&&!write_force&&rd_address[2:0]==0;
 wire write_allow=!fault&&pending<MAX_PENDING_WRITES;
 assign wr_ready=rst_n&&raw_wr_ready&&write_allow;
 assign wr_rsp_valid=rst_n&&raw_rsp_valid;
 assign wr_rsp_error=raw_rsp_error||fault;
 assign raw_rd_valid=rst_n&&rd_valid&&read_allow;
 assign rd_ready=rst_n&&raw_rd_ready&&read_allow;
 assign rd_data_valid=rst_n&&raw_data_valid;assign rd_data=raw_data;assign rd_last=raw_last;
 assign quiet=rst_n&&initialized&&pending==0&&!read_active&&!raw_rsp_valid&&!wr_valid&&!rd_valid;
 assign sdram_clk=forwarded_clk;
 wire put=wr_valid&&wr_ready,ack=wr_rsp_valid&&wr_rsp_ready;
 wire get=rd_valid&&rd_ready;
 sdram_burst_controller #(.POWER_CYCLES(POWER_CYCLES),.REFRESH_CYCLES(REFRESH_CYCLES)) controller(
  .clk(clk),.rst_n(rst_n),.initialized(initialized),.write_window(1'b1),
  .wr_valid(wr_valid&&write_allow),.wr_ready(raw_wr_ready),.wr_address(wr_address),.wr_data(wr_data),
  .wr_rsp_valid(raw_rsp_valid),.wr_rsp_ready(wr_rsp_ready),.wr_rsp_error(raw_rsp_error),
  .rd_valid(raw_rd_valid),.rd_ready(raw_rd_ready),.rd_address(rd_address),
  .rd_data_valid(raw_data_valid),.rd_data(raw_data),.rd_last(raw_last),.protocol_error(raw_protocol_error),
  .sdram_clk(unused_inverted_clock),.sdram_ras_n(sdram_ras_n),.sdram_cas_n(sdram_cas_n),.sdram_we_n(sdram_we_n),
  .sdram_addr(sdram_addr),.sdram_ba(sdram_ba),.sdram_dqm(sdram_dqm),.sdram_dq(sdram_dq));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin pending<=0;write_age<=0;read_active<=0;read_beat<=0;fault<=0;write_acks<=0;read_bursts<=0;refresh_count<=0;end
  else begin
   case({put,ack})2'b10:pending<=pending+1'b1;2'b01:if(pending!=0)pending<=pending-1'b1;default:;endcase
   if(ack)begin
    if(pending==0)fault<=1;
    if(write_acks!=32'hffffffff)write_acks<=write_acks+1'b1;
   end
   if(pending==0||raw_rsp_valid)write_age<=0;
   else if(write_age<WRITE_WAIT_CYCLES)write_age<=write_age+1'b1;
   if(raw_protocol_error||(rd_valid&&rd_address[2:0]!=0))fault<=1;
   if(get)begin read_active<=1;read_beat<=0;end
   if(raw_data_valid)begin
    if(!read_active||raw_last!=(read_beat==7))fault<=1;
    if(read_beat==7)begin
     read_active<=0;read_beat<=0;
     if(read_bursts!=32'hffffffff)read_bursts<=read_bursts+1'b1;
    end else read_beat<=read_beat+1'b1;
   end
   if(initialized&&!sdram_ras_n&&!sdram_cas_n&&sdram_we_n&&refresh_count!=32'hffffffff)refresh_count<=refresh_count+1'b1;
  end
 end
endmodule
