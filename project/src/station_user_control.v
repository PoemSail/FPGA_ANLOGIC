`timescale 1ns/1ps
// C5/E4/F4. Menu0: music service / route (normal:next photo) / play-pause.
// Hold F4 cycles play,B,G,V,normal-media,transition,photo-navigation.
// Hold C5: manual route service. Hold E4: auto brightness toggle.
module station_user_control(
 input wire clk,rst_n,frame_commit,input wire [2:0] short_press,long_press,
 input wire emergency_active,input wire [1:0] active_scene,input wire music_fault,
 output reg manual_service_pulse,output reg music_selected,music_playing,normal_playing,
 output reg [1:0] normal_media,output reg [2:0] menu,
 output reg auto_brightness,output reg signed [7:0] manual_brightness,
 output reg [8:0] contrast,output reg [3:0] volume,output reg [1:0] transition,
 output reg photo_next,photo_previous,output reg retry_music
);
 reg [8:0] pending_contrast;reg [3:0] pending_volume;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   manual_service_pulse<=0;music_selected<=0;music_playing<=1;normal_playing<=1;
   normal_media<=2;menu<=0;auto_brightness<=1;manual_brightness<=0;
   contrast<=256;pending_contrast<=256;volume<=8;pending_volume<=8;
   transition<=1;photo_next<=0;photo_previous<=0;retry_music<=0;
  end else begin
   manual_service_pulse<=0;photo_next<=0;photo_previous<=0;retry_music<=0;
   if(frame_commit)begin contrast<=pending_contrast;volume<=pending_volume;end
   if(!emergency_active)begin
    if(long_press[2])menu<=menu==6?0:menu+1'b1;
    if(long_press[1])auto_brightness<=!auto_brightness;
    if(long_press[0])begin music_selected<=0;manual_service_pulse<=1;menu<=0;end
    if(short_press[2])begin
     if(music_selected||normal_media==1)begin
      if(music_fault)begin retry_music<=1;music_playing<=1;end
      else music_playing<=!music_playing;
     end else normal_playing<=!normal_playing;
    end
    if(short_press[0]||short_press[1])begin
     case(menu)
      0:if(short_press[0])begin
         music_selected<=1;music_playing<=1;manual_service_pulse<=1;
        end else if(active_scene==1||music_selected)begin
         music_selected<=0;manual_service_pulse<=1;
        end else if(normal_media==0)photo_next<=1;
      1:if(!auto_brightness)begin
         if(short_press[0])begin if(manual_brightness>-64)manual_brightness<=manual_brightness-8;end
         else if(manual_brightness<64)manual_brightness<=manual_brightness+8;
        end
      2:if(short_press[0])begin if(pending_contrast>128)pending_contrast<=pending_contrast-16;end
        else if(pending_contrast<384)pending_contrast<=pending_contrast+16;
      3:if(short_press[0])begin if(pending_volume>0)pending_volume<=pending_volume-1'b1;end
        else if(pending_volume<15)pending_volume<=pending_volume+1'b1;
      4:if(short_press[0])normal_media<=normal_media==0?2:normal_media-1'b1;
        else normal_media<=normal_media==2?0:normal_media+1'b1;
      5:if(short_press[0])transition<=transition==0?2:transition-1'b1;
        else transition<=transition==2?0:transition+1'b1;
      6:if(normal_media==0)begin
         if(short_press[0])photo_previous<=1;else photo_next<=1;
        end
     endcase
    end
   end
  end
 end
endmodule
