`timescale 1ns/1ps
// Business-clock actual-parameter OSD lifetime. Feed effective brightness,
// contrast and volume, not key targets. Existing coherent UI mailbox carries
// display_menu instead of user_menu; no wider pixel snapshot is required.
// Timing is HOLD_FRAMES frame intervals after the last actual change. On reset
// the first committed snapshot establishes a baseline without a startup popup.
module station_parameter_osd #(
 parameter integer HOLD_FRAMES=180,COUNTER_BITS=8
)(
 input wire clk,rst_n,frame_commit,
 input wire signed [7:0] brightness,input wire [8:0] contrast,input wire [3:0] volume,
 input wire automatic_brightness,input wire [2:0] user_menu,
 output wire visible,output wire [2:0] display_menu,
 output reg [1:0] last_kind,output reg [COUNTER_BITS-1:0] remaining
);
 reg initialized,previous_auto;reg signed [7:0] previous_brightness;
 reg [8:0] previous_contrast;reg [3:0] previous_volume;
 wire changed_b=brightness!=previous_brightness||automatic_brightness!=previous_auto;
 wire changed_c=contrast!=previous_contrast;
 wire changed_v=volume!=previous_volume;
 wire parameter_menu=user_menu>=1&&user_menu<=3;
 assign visible=rst_n&&(parameter_menu||remaining!=0);
 // Every explicit user menu retains priority; last parameter reappears when
 // returning to menu0 if its lifetime has not expired. Emergency rendering
 // suppresses this menu through the existing scene priority in the renderer.
 assign display_menu=user_menu!=0?user_menu:((remaining!=0)?{1'b0,last_kind}:3'd0);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   initialized<=0;previous_auto<=0;previous_brightness<=0;previous_contrast<=256;previous_volume<=8;
   last_kind<=0;remaining<=0;
  end else if(frame_commit)begin
   initialized<=1;previous_auto<=automatic_brightness;previous_brightness<=brightness;
   previous_contrast<=contrast;previous_volume<=volume;
   if(initialized&&(changed_b||changed_c||changed_v))begin
    remaining<=HOLD_FRAMES;last_kind<=changed_b?1:changed_c?2:3;
   end else if(remaining!=0)remaining<=remaining-1'b1;
  end
 end
endmodule
