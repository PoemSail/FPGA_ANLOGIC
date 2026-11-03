`timescale 1ns/1ps
// Mapping for the 960x540 station viewport at (32,72) in a 1280x720 raster.
// S0: 3x integer repeat; S1: 2x repeat. No divider, DSP or frame buffer.
// Raster contract: one pixel/clock, x=0..1649, y=0..749, no coordinate stalls.
module station_media_coordinates(
 input wire pixel_clk,rst_n,large_profile,input wire [11:0] x,y,
 output wire active,prefetch,first_pixel,output wire [8:0] source_x,source_y
);
 reg [8:0] sx,sy;reg [1:0] hx,vy;
 wire [1:0] repeat_last=large_profile?2'd1:2'd2;
 assign active=x>=32&&x<992&&y>=72&&y<612;
 assign prefetch=y<72||y>=720;
 assign first_pixel=x==32;
 assign source_x=x==32?9'd0:sx;
 assign source_y=sy;
 always @(posedge pixel_clk or negedge rst_n)begin
  if(!rst_n)begin sx<=0;sy<=0;hx<=0;vy<=0;end
  else begin
   if(x==0&&y==72)begin sy<=0;vy<=0;end
   if(x==1649&&y>=72&&y<612)begin
    if(vy==repeat_last)begin vy<=0;sy<=sy+1'b1;end else vy<=vy+1'b1;
   end
   if(active)begin
    if(x==32)begin sx<=0;hx<=1;end
    else if(hx==repeat_last)begin hx<=0;sx<=sx+1'b1;end
    else hx<=hx+1'b1;
   end
  end
 end
endmodule
