// Adapted from reviewed pcm_playback_fifo_av_r20; phase remains in the shared external tick.
`timescale 1ns/1ps
// Bounded PCM jitter buffer. Prefill/rebuffer prevents free-running consumer
// from turning variable SD latency into stale samples. Underflow emits silence.
module station_pcm_fifo #(
 parameter integer DEPTH=1024,PREFILL=128,AW=10
)(
 input wire clk,rst_n,flush,physical_tick,in_valid,output wire in_ready,input wire [15:0] in_left,in_right,
 input wire eof,paused,
 output wire content_pop,content_available,output reg content_valid,
 output reg sample_valid,output reg signed [15:0] sample_left,sample_right,
 output wire [AW:0] level,output reg [31:0] underruns,output reg playing,output wire drained
);
 reg [31:0] ram[0:DEPTH-1];reg [AW-1:0] wp,rp;reg [AW:0] count;
 reg [31:0] front;reg front_valid;
 wire tick=physical_tick;
 wire push=in_valid&&in_ready;
 wire pop=tick&&playing&&!paused&&front_valid&&!flush;
 assign content_pop=rst_n&&pop;assign content_available=rst_n&&playing&&front_valid;
 assign in_ready=rst_n&&!flush&&count<DEPTH;assign level=count;assign drained=eof&&count==0;
 always @(posedge clk)begin
  if(push)ram[wp]<={in_left,in_right};
  if(!front_valid&&count!=0)front<=ram[rp];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin wp<=0;rp<=0;count<=0;front_valid<=0;sample_valid<=0;content_valid<=0;sample_left<=0;sample_right<=0;underruns<=0;playing<=0;end
  else if(flush)begin
   wp<=0;rp<=0;count<=0;front_valid<=0;playing<=0;
   sample_valid<=0;content_valid<=0;sample_left<=0;sample_right<=0;
  end else begin
   sample_valid<=0;content_valid<=0;
   if(push)wp<=wp+1'b1;
   if(!front_valid&&count!=0)front_valid<=1;
   if(pop)begin content_valid<=1;rp<=rp+1'b1;front_valid<=0;if(eof&&count==1&&!push)playing<=0;end
   case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
   if(!playing&&(count>=PREFILL||(eof&&count!=0)))playing<=1;
   if(tick)begin
    sample_valid<=1;sample_left<=0;sample_right<=0;
    if(pop)begin sample_left<=front[31:16];sample_right<=front[15:0];end
    else if(playing&&!paused)begin
     playing<=0;if(!eof)underruns<=underruns+1'b1;
    end
   end
  end
 end
endmodule
