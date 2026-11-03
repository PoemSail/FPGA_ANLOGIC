`timescale 1ns/1ps
// Pixel-domain renderer. ALL control/FFT inputs are already one coherent snapshot.
// Three registered stages preserve pixel valid/coordinates/sync under input stalls.
module station_service_view(
 input wire clk,rst_n,input wire in_valid,in_de,in_hs,in_vs,
 input wire [11:0] in_x,in_y,input wire [23:0] media_rgb,
 input wire [1:0] scene,normal_media,transition,input wire music_selected,music_playing,
 input wire [255:0] levels,input wire [2:0] menu,input wire [3:0] volume,
 input wire signed [7:0] brightness,input wire [8:0] contrast,
 input wire auto_brightness,light_known,dark,input wire [9:0] scroll,
 input wire [7:0] arrival1,arrival2,
 output reg out_valid,out_de,out_hs,out_vs,output reg [11:0] out_x,out_y,output reg [23:0] out_rgb
);
 reg [23:0] base;reg text_enable,direct;reg [4:0] label_id,column;
 reg [7:0] direct_glyph;reg [3:0] gx,gy;
 integer tx,band,h;reg [8:0] number;
 function [7:0] effect;
  input [7:0] c;input signed [7:0] b;input [8:0] gain;
  reg signed [19:0] centered,product,value;
  begin centered=$signed({1'b0,c})-20'sd128;product=centered*$signed({1'b0,gain});
   value=(product>>>8)+20'sd128+b;effect=value<0?0:value>255?255:value[7:0];end
 endfunction
 always @*begin
  base=24'h102030;text_enable=0;label_id=0;column=0;gx=0;gy=0;direct=0;direct_glyph=96;
  tx=0;band=0;h=0;number=0;
  if(in_x>=32&&in_x<992&&in_y>=72&&in_y<612)begin
   if(scene==0)base={effect(media_rgb[23:16],brightness,contrast),effect(media_rgb[15:8],brightness,contrast),effect(media_rgb[7:0],brightness,contrast)};
   else if(scene==1)base=24'h15394d;
  end
  if(in_x>=1024&&in_x<1248&&in_y>=72&&in_y<612)base=24'h183a4b;
  if(scene==1&&!music_selected)begin
   if(in_x>=96&&in_x<928&&((in_y>=300&&in_y<308)||(in_y>=460&&in_y<468)))base=24'h28bd9c;
   if(in_x>=96&&in_x<928&&((in_x-96)%200<24)&&
     ((in_y>=292&&in_y<316)||(in_y>=452&&in_y<476)))base=24'hffffff;
  end
  if((scene==1&&music_selected)||(scene==0&&normal_media==1))begin
   if(in_x>=48&&in_x<976&&in_y>=384&&in_y<592)begin
    band=(in_x-48)/29;h=levels[band*8+:8];
    if((in_x-48)%29<22&&in_y>=576-h&&in_y<576)base=24'h20ddb0;
    else base=24'h0b2538;
   end
  end
  if(scene==2)base=24'h432513;
  if(scene==3)begin
   base=24'h9c1820;
   if(in_x>=1100&&in_x<1180&&in_y>=120&&in_y<240)base=24'hfff0b0;
   if(in_x>=1100&&in_x<1180&&in_y>=264&&in_y<300)base=24'hfff0b0;
  end
  if(in_y>=16&&in_y<48&&in_x>=32&&in_x<512)begin text_enable=1;label_id=0;tx=in_x-32;gy=(in_y-16)>>1;end
  else if(in_y>=16&&in_y<48&&in_x>=1024&&in_x<1248)begin text_enable=1;label_id=1;tx=in_x-1024;gy=(in_y-16)>>1;end
  else if(in_y>=96&&in_y<128&&in_x>=64&&in_x<992)begin
   text_enable=1;label_id=scene==3?8:scene==2?10:scene==1?(music_selected?3:2):normal_media==1?20:normal_media==0?19:18;
   tx=in_x-64;gy=(in_y-96)>>1;
  end
  else if(in_y>=160&&in_y<192&&in_x>=64&&in_x<992&&scene==1)begin
   text_enable=1;label_id=music_selected?(music_playing?5:6):4;tx=in_x-64;gy=(in_y-160)>>1;
  end
  else if(in_y>=224&&in_y<256&&in_x>=64&&in_x<1088&&scene>=2)begin
   text_enable=1;label_id=scene==3?9:11;tx=in_x-64;gy=(in_y-224)>>1;
  end
  else if(scene==1&&!music_selected&&((in_y>=240&&in_y<272)||(in_y>=400&&in_y<432))&&in_x>=64&&in_x<256)begin
   text_enable=1;label_id=12;tx=in_x-64;gy=in_y>=400?(in_y-400)>>1:(in_y-240)>>1;
   if(in_x>=160)begin direct=1;direct_glyph=in_x<192?(in_y>=400?114:113):96;end
  end
  else if(scene<2&&in_y>=160&&in_y<192&&in_x>=1040&&in_x<1248)begin
   text_enable=1;label_id=25;tx=in_x-1040;gy=(in_y-160)>>1;
  end
  else if(scene<2&&in_y>=224&&in_y<256&&in_x>=1040&&in_x<1136)begin
   text_enable=1;direct=1;tx=in_x-1040;gy=(in_y-224)>>1;
   number=arrival1;direct_glyph=112+((in_x-1040)/32==0?number/100:(in_x-1040)/32==1?(number/10)%10:number%10);
  end
  else if(scene<2&&in_y>=320&&in_y<352&&in_x>=1040&&in_x<1136)begin
   text_enable=1;direct=1;tx=in_x-1040;gy=(in_y-320)>>1;
   number=arrival2;direct_glyph=112+((in_x-1040)/32==0?number/100:(in_x-1040)/32==1?(number/10)%10:number%10);
  end
  else if(scene<2&&in_y>=448&&in_y<480&&in_x>=1040&&in_x<1248)begin
   text_enable=1;label_id=auto_brightness?14:15;tx=in_x-1040;gy=(in_y-448)>>1;
  end
  else if(scene<2&&in_y>=512&&in_y<544&&in_x>=1040&&in_x<1248&&light_known)begin
   text_enable=1;label_id=dark?29:28;tx=in_x-1040;gy=(in_y-512)>>1;
  end
  else if(in_y>=640&&in_y<672&&in_x>=32&&in_x<1248)begin
   base=scene==3?24'h701018:24'h102030;text_enable=1;label_id=scene==3?9:7;
   tx=in_x-32+scroll;gy=(in_y-640)>>1;
  end
  // Parameter menu replaces a bounded strip; values are committed inputs only.
  if(menu!=0&&scene<2&&in_y>=576&&in_y<608&&in_x>=64&&in_x<640)begin
   base=24'h24364a;text_enable=1;direct=0;tx=in_x-64;gy=(in_y-576)>>1;
   case(menu)1:label_id=16;2:label_id=17;3:label_id=13;4:label_id=normal_media==0?19:normal_media==1?20:18;5:label_id=21;default:label_id=22;endcase
   if(in_x>=224&&in_x<352&&menu!=4&&menu!=6)begin
    direct=1;tx=in_x-224;
    case(menu)1:number=brightness[7]?-brightness:brightness;2:number=contrast;3:number=volume;default:number=transition;endcase
    if(in_x<256)direct_glyph=menu==1&&brightness[7]?109:96;
    else direct_glyph=112+((in_x-256)/32==0?number/100:(in_x-256)/32==1?(number/10)%10:number%10);
   end
  end
  column=(tx>>5)&31;gx=(tx>>1)&15;
  if(!in_de)begin base=0;text_enable=0;end
 end
 wire [7:0] rom_glyph;reg a_direct,a_text,a_valid,a_de,a_hs,a_vs;
 reg [7:0] a_glyph;reg [3:0] a_gx,a_gy;reg [23:0] a_rgb;reg [11:0] a_x,a_y;
 wire ink;station_text_rom text_rom(.clk(clk),.label_id(label_id),.column(column),.glyph(rom_glyph));
 station_font_rom font_rom(.clk(clk),.glyph(a_direct?a_glyph:rom_glyph),.x(a_gx),.y(a_gy),.ink(ink));
 reg b_text,b_valid,b_de,b_hs,b_vs;reg [23:0] b_rgb;reg [11:0] b_x,b_y;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   a_direct<=0;a_text<=0;a_valid<=0;a_de<=0;a_hs<=0;a_vs<=0;a_glyph<=96;a_gx<=0;a_gy<=0;a_rgb<=0;a_x<=0;a_y<=0;
   b_text<=0;b_valid<=0;b_de<=0;b_hs<=0;b_vs<=0;b_rgb<=0;b_x<=0;b_y<=0;
   out_valid<=0;out_de<=0;out_hs<=0;out_vs<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   a_valid<=in_valid;a_direct<=direct;a_glyph<=direct_glyph;a_text<=text_enable;a_gx<=gx;a_gy<=gy;
   a_rgb<=base;a_x<=in_x;a_y<=in_y;a_de<=in_de;a_hs<=in_hs;a_vs<=in_vs;
   b_valid<=a_valid;b_text<=a_text;b_rgb<=a_rgb;b_x<=a_x;b_y<=a_y;b_de<=a_de;b_hs<=a_hs;b_vs<=a_vs;
   out_valid<=b_valid;out_rgb<=!b_de?0:(b_text&&ink)?24'hffffff:b_rgb;
   out_x<=b_x;out_y<=b_y;out_de<=b_de;out_hs<=b_hs;out_vs<=b_vs;
  end
 end
endmodule
