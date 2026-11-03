`timescale 1ns/1ps
// Business-clock owner of two acknowledged photo surfaces. Publication and
// video/photo source changes occur only in the pixel bridge's drained window.
// The bridge must clear its old pixel banks BEFORE asserting frame_boundary.
// Common reset with allocator/bridge/DMA is required. Release has no backpressure.
module station_visual_surface #(
 parameter [20:0] PHOTO_BASE0=21'h40000,PHOTO_BASE1=21'h52000
)(
 input wire clk,rst_n,frame_boundary,pixel_swap_safe,line_idle,
 input wire request_photo,input wire memory_fault,
 input wire descriptor_valid,output wire descriptor_ready,input wire descriptor_error,
 input wire [20:0] descriptor_base,input wire descriptor_slot,input wire [15:0] descriptor_generation,
 output reg release_valid,release_slot,output reg [15:0] release_generation,
 input wire video_valid,video_slot,video_publish,input wire [63:0] video_pts,
 input wire [15:0] video_width,video_height,
 output wire display_valid,output wire [20:0] display_base,output wire [63:0] display_pts,
 output wire [15:0] display_width,display_height,output wire publish,
 output reg selected_photo,output reg front_valid,front_slot,output reg [15:0] front_generation,
 output reg pending_valid,output reg load_error,output reg fault
);
 reg pending_slot;reg [15:0] pending_generation;
 wire window=frame_boundary&&pixel_swap_safe&&line_idle&&!fault&&!memory_fault;
 wire accept=descriptor_valid&&descriptor_ready;
 wire descriptor_ok=descriptor_generation!=0&&
  descriptor_base==(descriptor_slot?PHOTO_BASE1:PHOTO_BASE0)&&
  !(front_valid&&descriptor_slot==front_slot);
 assign descriptor_ready=rst_n&&!pending_valid&&!fault&&!memory_fault;
 assign publish=rst_n&&((window&&(request_photo!=selected_photo||pending_valid))||(!selected_photo&&video_publish));
 assign display_valid=rst_n&&!fault&&!memory_fault&&(selected_photo?front_valid:video_valid);
 assign display_base=selected_photo?(front_slot?PHOTO_BASE1:PHOTO_BASE0):(video_slot?21'h12000:21'd0);
 assign display_pts=selected_photo?{47'd0,front_generation,front_slot}:video_pts;
 assign display_width=selected_photo?16'd480:video_width;
 assign display_height=selected_photo?16'd270:video_height;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   release_valid<=0;release_slot<=0;release_generation<=0;
   selected_photo<=0;front_valid<=0;front_slot<=0;front_generation<=0;
   pending_valid<=0;pending_slot<=0;pending_generation<=0;load_error<=0;fault<=0;
  end else begin
   release_valid<=0;load_error<=0;
   if(memory_fault)fault<=1;
   if(accept)begin
    if(descriptor_error)load_error<=1;
    else if(!descriptor_ok)fault<=1;
    else begin pending_valid<=1;pending_slot<=descriptor_slot;pending_generation<=descriptor_generation;end
   end
   if(window)begin
    selected_photo<=request_photo;
    if(pending_valid)begin
     if(front_valid)begin release_valid<=1;release_slot<=front_slot;release_generation<=front_generation;end
     front_valid<=1;front_slot<=pending_slot;front_generation<=pending_generation;pending_valid<=0;
    end
   end
  end
 end
endmodule
