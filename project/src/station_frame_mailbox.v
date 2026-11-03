`timescale 1ns/1ps
// Bundled-data req/ack mailbox; producer coalesces latest state while busy.
// Both domains MUST share reset assertion. No independent-domain reset protocol.
module station_frame_mailbox #(parameter integer WIDTH=32)(
 input wire src_clk,dst_clk,arst_n,input wire [WIDTH-1:0] src_data,
 input wire src_valid,output wire src_ready,input wire dst_frame,
 output reg [WIDTH-1:0] dst_data,output reg dst_valid
);
 wire srst,drst;reset_sync sreset(.clk(src_clk),.arst_n(arst_n),.rst_n(srst));
 reset_sync dreset(.clk(dst_clk),.arst_n(arst_n),.rst_n(drst));
 reg request,ack;reg ack_meta,ack_sync,req_meta,req_sync;reg [WIDTH-1:0] held;
 assign src_ready=srst&&(ack_sync==request);
 always @(posedge src_clk or negedge srst)begin
  if(!srst)begin request<=0;held<=0;ack_meta<=0;ack_sync<=0;end
  else begin
   ack_meta<=ack;ack_sync<=ack_meta;
   if(src_valid&&src_ready)begin held<=src_data;request<=!request;end
  end
 end
 always @(posedge dst_clk or negedge drst)begin
  if(!drst)begin ack<=0;req_meta<=0;req_sync<=0;dst_data<=0;dst_valid<=0;end
  else begin
   req_meta<=request;req_sync<=req_meta;
   if(dst_frame&&req_sync!=ack)begin dst_data<=held;dst_valid<=1;ack<=req_sync;end
  end
 end
endmodule
