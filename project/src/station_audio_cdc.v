`timescale 1ns/1ps
// Stereo sample stream crosses business -> pixel with a Gray-pointer FIFO.
// Common async reset assertion required. No one-sided reset protocol.
// AW >= 2, DEPTH=2**AW. Source is real-time: reject full writes and count them.
// Data stays stable while dst_valid && !dst_ready. No reset on RAM contents.
// Physical synchronizer/Gray bus-skew constraints are still required.
module station_audio_cdc #(parameter integer AW=5)(
 input wire src_clk,dst_clk,arst_n,
 input wire src_valid,input wire [15:0] src_left,src_right,output wire src_ready,
 output wire dst_valid,input wire dst_ready,output wire [15:0] dst_left,dst_right,
 output reg overflow,output reg [31:0] dropped
);
 wire srst,drst;reset_sync sr(.clk(src_clk),.arst_n(arst_n),.rst_n(srst));
 reset_sync dr(.clk(dst_clk),.arst_n(arst_n),.rst_n(drst));
 reg [31:0] ram[0:(1<<AW)-1];reg [AW:0] wb,wg,rb,rg;
 reg [AW:0] rm,rs,wm,ws;reg full,empty,front_valid;reg [31:0] front;
 wire push=src_valid&&src_ready,pop=dst_valid&&dst_ready;
 wire [AW:0] wn=wb+push,rn=rb+pop;
 wire [AW:0] wgn=(wn>>1)^wn,rgn=(rn>>1)^rn;
 wire full_next=wgn=={~rs[AW:AW-1],rs[AW-2:0]};
 wire empty_next=rgn==ws;
 assign src_ready=srst&&!full;
 assign dst_valid=drst&&front_valid;
 assign dst_left=front[15:0];assign dst_right=front[31:16];
 always @(posedge src_clk)if(push)ram[wb[AW-1:0]]<={src_right,src_left};
 always @(posedge dst_clk)if(!front_valid&&!empty)front<=ram[rb[AW-1:0]];
 always @(posedge src_clk or negedge srst)begin
  if(!srst)begin wb<=0;wg<=0;rm<=0;rs<=0;full<=0;overflow<=0;dropped<=0;end
  else begin
   rm<=rg;rs<=rm;wb<=wn;wg<=wgn;full<=full_next;
   if(src_valid&&!src_ready)begin overflow<=1;if(dropped!=32'hffffffff)dropped<=dropped+1'b1;end
  end
 end
 always @(posedge dst_clk or negedge drst)begin
  if(!drst)begin rb<=0;rg<=0;wm<=0;ws<=0;empty<=1;front_valid<=0;end
  else begin
   wm<=wg;ws<=wm;rb<=rn;rg<=rgn;empty<=empty_next;
   if(!front_valid&&!empty)front_valid<=1;
   if(pop)front_valid<=0;
  end
 end
endmodule
