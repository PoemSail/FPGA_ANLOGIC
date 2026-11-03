`timescale 1ns/1ps
// One real pixel clock; 1280x720 active in1650x750, positive sync (VIC4).
// PLL/DDR physical feasibility is a separate gate, not established by this module.
module station_video_timing(input wire pixel_clk,rst_n,
 output reg [11:0] x,y,output wire de,hs,vs,frame_start,vblank_start);
 assign de=rst_n&&x<1280&&y<720;
 assign hs=rst_n&&x>=1390&&x<1430;
 assign vs=rst_n&&y>=725&&y<730;
 assign frame_start=rst_n&&x==0&&y==0;
 assign vblank_start=rst_n&&x==0&&y==720;
 always @(posedge pixel_clk or negedge rst_n)begin
  if(!rst_n)begin x<=0;y<=0;end
  else if(x==1649)begin x<=0;y<=y==749?0:y+1'b1;end
  else x<=x+1'b1;
 end
endmodule
