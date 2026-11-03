`timescale 1ns/1ps
// Keep the raster/UI clock running while the media bridge is group-reset.
// media_rgb already has the original bridge's TWO-register pixel latency.
// All descriptor/line-buffer clients must share media_arst_n assertion;
// this guard does not make one-sided client resets safe.
module station_recovery_raster_guard(
 input wire bus_clk,pixel_clk,global_arst_n,media_arst_n,
 input wire [11:0] x,y,input wire de,hs,vs,vblank_start,
 input wire [23:0] media_rgb,
 output reg [11:0] out_x,out_y,output reg out_de,out_hs,out_vs,
 output wire [23:0] out_rgb,output reg business_frame_commit,
 output wire media_pixels_enabled
);
 wire brst,prst,mrst;
 reset_sync bus_reset(.clk(bus_clk),.arst_n(global_arst_n),.rst_n(brst));
 reset_sync pixel_reset(.clk(pixel_clk),.arst_n(global_arst_n),.rst_n(prst));
 reset_sync media_reset(.clk(pixel_clk),.arst_n(global_arst_n&&media_arst_n),.rst_n(mrst));
 reg [11:0] first_x,first_y;
 reg first_de,first_hs,first_vs,frame_toggle;
 reg [1:0] media_warmup;
 reg frame_meta,frame_sync,frame_seen;
 assign media_pixels_enabled=mrst&&media_warmup[1];
 assign out_rgb=media_pixels_enabled?media_rgb:24'd0;
 always @(posedge pixel_clk or negedge prst)begin
  if(!prst)begin
   first_x<=0;first_y<=0;first_de<=0;first_hs<=0;first_vs<=0;
   out_x<=0;out_y<=0;out_de<=0;out_hs<=0;out_vs<=0;frame_toggle<=0;
  end else begin
   first_x<=x;first_y<=y;first_de<=de;first_hs<=hs;first_vs<=vs;
   out_x<=first_x;out_y<=first_y;out_de<=first_de;out_hs<=first_hs;out_vs<=first_vs;
   if(vblank_start)frame_toggle<=!frame_toggle;
  end
 end
 always @(posedge pixel_clk or negedge mrst)begin
  if(!mrst)media_warmup<=0;
  else media_warmup<={media_warmup[0],1'b1};
 end
 // Only the event toggle crosses; coordinates remain in the pixel domain.
 // A complete video frame must exceed the bus synchronizer latency.
 always @(posedge bus_clk or negedge brst)begin
  if(!brst)begin frame_meta<=0;frame_sync<=0;frame_seen<=0;business_frame_commit<=0;end
  else begin
   frame_meta<=frame_toggle;frame_sync<=frame_meta;frame_seen<=frame_sync;
   business_frame_commit<=frame_sync!=frame_seen;
  end
 end
endmodule
