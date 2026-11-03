// A stores independent base-region events; B resolves priority, same4pixel public latency.
// Internal4bit static base code, decoded in existingBstage; public4pixel latency unchanged.
// Candidate20261031: FOUR pixel stages, supersedes historical3stage comments.
// Night light theme 20261030: vertical-blank palette commit, unchanged 3-cycle interface.

// Passenger UI20261028: approved static3/5min route cards plus existing live32bin FFT.

// Independent parallel-font candidate; parent SHA256 85c6b477956f39ec8aa41bd9d92c7f9a860376aa56572f8b833e76e62611e563

// Unselected fixed-test-tone derivative; parent SHA256 0c797d796e109f33395847ef0c537b49402d03fa0265e4d5fda1f0220eb0797c

// Independent color-product stage candidate; same three-stage pixels.



// Isolated exact low-bit font-row candidate; same pixel contract.



// Isolated parallel-threshold candidate; same three pixel stages.



// Isolated FFT x-ROM candidate; same public pixel latency.



// Synchronous512x12 numeric ROM; original renderer preserved.



// Shared numeric conversion, original public interface and pixel latency.



// Exact compact coordinate/effect math; same renderer module name.



// Bounded-coordinate derivative; same module name, choose one renderer.



// Status-OSD derivative; native-verified recovery branch preserved.



`timescale 1ns/1ps



// Pixel-domain renderer. ALL control/FFT inputs are already one coherent snapshot.



// Three registered stages preserve pixel valid/coordinates/sync under input stalls.



module station_service_view_status #(parameter integer STREAM_SPECTRUM=0,parameter integer PIXEL_HEIGHT_SPECTRUM=0,parameter integer DOT_PALETTE_PORTABLE=0)(



 input wire clk,rst_n,input wire in_valid,in_de,in_hs,in_vs,



 input wire [11:0] in_x,in_y,input wire [23:0] media_rgb,



 input wire [1:0] scene,normal_media,transition,input wire music_selected,music_playing,



 input wire [7:0] spectrum_stream_level,output wire [4:0] spectrum_stream_address,output wire spectrum_frame_tick,

 input wire [255:0] levels,input wire [2:0] menu,input wire [3:0] volume,



 input wire signed [7:0] brightness,input wire [8:0] contrast,



 input wire [10:0] recovery_status,



 input wire auto_brightness,light_known,dark,input wire [9:0] scroll,



 input wire [7:0] arrival1,arrival2,



 output reg out_valid,out_de,out_hs,out_vs,output reg [11:0] out_x,out_y,output reg [23:0] out_rgb



);



 reg [25:0] base_events;reg text_enable,direct;reg [5:0] label_id;reg [4:0] column;



 reg [7:0] direct_glyph;reg [3:0] gx,gy;



 integer tx;reg [8:0] number;



 // Service layout only; all other scenes retain their original renderer.

 wire service_ui=(scene==1);

 reg [5:0] service_frame;reg service_origin_seen;

 // Count accepted frame origins, never pixel clocks or stalled duplicates.

 always @(posedge clk or negedge rst_n)begin

  if(!rst_n)begin service_frame<=0;service_origin_seen<=0;end

  else if(in_valid)begin

   if(in_de&&in_x==0&&in_y==0)begin

    if(!service_origin_seen)service_frame<=service_frame==59?0:service_frame+1'b1;

    service_origin_seen<=1;

   end else service_origin_seen<=0;

  end

 end

 wire service_blink=(service_frame<30); // 30frames on/30frames dim at60Hz.

 wire [11:0] service_dot_x=in_x<244?12'd112:in_x<508?12'd376:

  in_x<772?12'd640:in_x<1036?12'd904:12'd1168;

 wire [11:0] service_dot_y=in_y<313?12'd248:12'd425;

 wire [11:0] service_dx=in_x>=service_dot_x?in_x-service_dot_x:service_dot_x-in_x;

 wire [11:0] service_dy=in_y>=service_dot_y?in_y-service_dot_y:service_dot_y-in_y;

 function [4:0] circle_span10;input [4:0] y;begin

  case(y)0:circle_span10=10;1,2,3,4:circle_span10=9;5,6:circle_span10=8;

   7:circle_span10=7;8:circle_span10=6;9:circle_span10=4;default:circle_span10=0;endcase

 end endfunction

 function [4:0] circle_span7;input [4:0] y;begin

  case(y)0:circle_span7=7;1,2,3:circle_span7=6;4:circle_span7=5;

   5:circle_span7=4;6:circle_span7=3;default:circle_span7=0;endcase

 end endfunction

 function [4:0] circle_span16;input [4:0] y;begin

  case(y)0:circle_span16=16;1,2,3,4,5:circle_span16=15;6,7:circle_span16=14;

   8,9:circle_span16=13;10:circle_span16=12;11:circle_span16=11;

   12:circle_span16=10;13:circle_span16=9;14:circle_span16=7;

   15:circle_span16=5;default:circle_span16=0;endcase

 end endfunction

 function [4:0] circle_span14;input [4:0] y;begin

  case(y)0:circle_span14=14;1,2,3,4,5:circle_span14=13;6,7:circle_span14=12;

   8:circle_span14=11;9:circle_span14=10;10:circle_span14=9;

   11:circle_span14=8;12:circle_span14=7;13:circle_span14=5;default:circle_span14=0;endcase

 end endfunction

 wire service_dot=service_dy<=10&&service_dx<=circle_span10(service_dy[4:0]);

 wire service_dot_inner=service_dy<=7&&service_dx<=circle_span7(service_dy[4:0]);

 wire service_target=(service_dot_x==640);

 wire service_halo=service_target&&service_blink&&service_dy<=16&&

  service_dx<=circle_span16(service_dy[4:0])&&

  !(service_dy<=14&&service_dx<=circle_span14(service_dy[4:0]));



 // Timing20261028r1: circle lookup occupies the existing A/B stages.

 localparam [16383:0] DOT_X_BITS={

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121110,

 256'h0f0e0d0c0b0a090807060504030201001f1e1d1c1b1a19181716151413121130,

 256'h2f2e2d2c2b2a292827262524232221202122232425262728292a2b2c2d2e2f30,

 256'h1112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f10,

 256'h1112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f10,

 256'h1112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f10,

 256'h1112131415161718191a1b1c1d1e1f0001020304030201001f1e1d1c1b1a1918,

 256'h17161514131211100f0e0d0c0b0a090807060504030201001f1e1d1c1b1a1918,

 256'h17161514131211100f0e0d0c0b0a090807060504030201001f1e1d1c1b1a1918,

 256'h17161514131211100f0e0d0c0b0a090807060504030201001f1e1d1c1b1a1918,

 256'h17161514131211302f2e2d2c2b2a292827262524232221202122232425262728,

 256'h292a2b2c2d2e2f301112131415161718191a1b1c1d1e1f000102030405060708,

 256'h090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f000102030405060708,

 256'h090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f000102030405060708,

 256'h090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f000102034443424140,

 256'h5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140,

 256'h5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140,

 256'h5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140,

 256'h5f5e5d5c5b5a595857565554535251706f6e6d6c6b6a69686766656463626160,

 256'h6162636465666768696a6b6c6d6e6f705152535455565758595a5b5c5d5e5f40,

 256'h4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f40,

 256'h4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f40,

 256'h4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f40,

 256'h41424384838281809f9e9d9c9b9a999897969594939291908f8e8d8c8b8a8988,

 256'h87868584838281809f9e9d9c9b9a999897969594939291908f8e8d8c8b8a8988,

 256'h87868584838281809f9e9d9c9b9a999897969594939291908f8e8d8c8b8a8988,

 256'h87868584838281809f9e9d9c9b9a999897969594939291b0afaeadacabaaa9a8,

 256'ha7a6a5a4a3a2a1a0a1a2a3a4a5a6a7a8a9aaabacadaeafb09192939495969798,

 256'h999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f909192939495969798,

 256'h999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f909192939495969798,

 256'h999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f909192939495969798,

 256'h999a9b9c9d9e9f8081828384838281809f9e9d9c9b9a99989796959493929190,

 256'h8f8e8d8c8b8a898887868584838281809f9e9d9c9b9a99989796959493929190,

 256'h8f8e8d8c8b8a898887868584838281809f9e9d9c9b9a99989796959493929190,

 256'h8f8e8d8c8b8a898887868584838281809f9e9d9c9b9a999897969594939291b0,

 256'hafaeadacabaaa9a8a7a6a5a4a3a2a1a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0,

 256'h9192939495969798999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f90,

 256'h9192939495969798999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f90,

 256'h9192939495969798999a9b9c9d9e9f808182838485868788898a8b8c8d8e8f90

};

 localparam [6143:0] DOT_Y_BITS={

 256'h59551349140f38d30b28920718510308101f79d71b69961759551349140f38d3,

 256'h0b28920718510308101f79d71b69961759551349140f38d30b28920718510308,

 256'h101f79d71b69961759551349140f38d30b28920718510308101f79d71b699617,

 256'h59551349140f38d30b28920718510308101f79d71b69961759551349140f38d3,

 256'h0b28920718510308101f79d71b69961759551349140f38d30b28920718510308,

 256'h101f79d71b69961759551349140f38d30b28920718510308101f79d71b699617,

 256'h59551349140f38d30b28920718510308101f79d71b69961759551349140f38d3,

 256'h0b28920718510308101f79d71b69961759551349140f38d30b28920718510308,

 256'h101f79d71b69961759551349140f38d30b28920718510308101f79d71b699617,

 256'h59551349140f38d30b28920718510308101f79d71b69961759551349140f38d3,

 256'h0b28920718510308101f79d71b69961759551349140f38d30b28920718510308,

 256'h101f79d71b69961759551349140f38d30b28920718510308101f79d71b699617,

 256'h59551349140f38d30b28920718510308101f79d71b69961759551349140f38d3,

 256'h0b28920718510308101f79d71b699617595513491c2fbadb2baa9a279a59238a,

 256'h18218a39259a7a29aabb2dbafc1149351559761969b71d79f001083105187209,

 256'h28b30d38f41149351559761969b71d79f00108310518720928b30d38f4114935,

 256'h155976185d65544d24503ce34c2ca2481c61440c20407de75c6da6585d65544d,

 256'h24503ce34c2ca2481c61440c20407de75c6da6585d65544d2470beeb6caeaa68,

 256'h9e69648e28608628e49669e8a6aaecb6ebf04524d45565d865a6dc75e7c00420,

 256'hc41461c824a2cc34e3d04524d45565d865a6dc75e7c00420c41461c824a2cc34,

 256'he3d04524d45565d865a6dc75e7c00420c41461c824a2cc34e3d04524d45565d8,

 256'h65a6dc75e7c00420c41461c824a2cc34e3d04524d45565d865a6dc75e7c00420,

 256'hc41461c824a2cc34e3d04524d45565d865a6dc75e7c00420c41461c824a2cc34,

 256'he3d04524d45565d865a6dc75e7c00420c41461c824a2cc34e3d04524d45565d8

};

 localparam [5119:0] DOT_SHAPE_BITS={

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000000,

 256'h0000000000000000000000000000000000000000000000000000000000000008,

 256'h0000000000000000000000000000000010842108000000000000000000000000,

 256'h000000421084210c0000000000000000000000000001084218c6318c00000000,

 256'h00000000000000000021086318c6318c00000000000000000000000004210c63,

 256'h18c6318c00000000000000000000000084218c6318c6318d0000000000000000,

 256'h0000001084318c6318d6b5ad00000000000000000000001086318c635ad6b5ad,

 256'h000000000000000000000210c6318c6b5ad6b5af000000000000000000000210,

 256'hc6318d6b5ad7bdef000000000000000000004218c6318d6b5af7bdef00000000,

 256'h0000000000004218c631ad6b5ef7bdef000000000000000000004218c631ad6b,

 256'hdeffffff000000000000000000004218c631ad6bdeffffff0000000000000000,

 256'h00004218c631ad6bdeffffff000000000000000000084318c635ad7bdeffffff

};

 reg [7:0] dot_x_rom[0:2047];reg [5:0] dot_y_rom[0:1023];reg [4:0] dot_shape_rom[0:1023];

 integer dot_init;

 initial begin

  for(dot_init=0;dot_init<2048;dot_init=dot_init+1)dot_x_rom[dot_init]=DOT_X_BITS[dot_init*8+:8];

  for(dot_init=0;dot_init<1024;dot_init=dot_init+1)begin

   dot_y_rom[dot_init]=DOT_Y_BITS[dot_init*6+:6];

   dot_shape_rom[dot_init]=DOT_SHAPE_BITS[dot_init*5+:5];

  end

 end

 reg [7:0] a_dot_x;reg [5:0] a_dot_y;reg [4:0] b_dot_shape;

 always @(posedge clk)begin

  a_dot_x<=dot_x_rom[in_x[10:0]];a_dot_y<=dot_y_rom[in_y[9:0]];

  b_dot_shape<=dot_shape_rom[{a_dot_y[4:0],a_dot_x[4:0]}];

 end

 reg a_dot_in_bounds,a_dot_blink;

 reg b_dot_valid,b_dot_blink,b_dot_target,b_dot_past;

 wire dot_halo_overlay=b_dot_valid&&b_dot_target&&b_dot_blink&&b_dot_shape[3]&&!b_dot_shape[2];

 wire dot_disk_overlay=b_dot_valid&&b_dot_shape[0];

 reg a_theme,b_theme,a_theme_media,b_theme_media;

 reg signed [7:0] a_theme_brightness,b_theme_brightness;
 wire [23:0] light_halo_b,light_muted_b,light_teal_b,light_inner_b;
 station_dot_palette32k #(.PORTABLE(DOT_PALETTE_PORTABLE)) dot_palette(
  .clk(clk),.rst_n(rst_n),.brightness(a_theme_brightness),
  .halo(light_halo_b),.muted(light_muted_b),.teal(light_teal_b),.inner(light_inner_b));

 wire [23:0] dot_disk_rgb=!b_dot_shape[1]?

  (b_dot_target?(b_dot_blink?(b_theme?24'ha76017:24'hffbc66):(b_theme?24'ha8b5c1:24'h536d83)):

   b_dot_past?(b_theme?24'h299b8e:24'h28c8ad):(b_theme?24'ha8b5c1:24'h536d83)):

  (b_dot_past&&b_dot_shape[4]?(b_theme?24'h299b8e:24'h28c8ad):(b_theme?24'hfcfcfa:24'h142a3c));

 wire [23:0] final_base_rgb;



 // Night light theme, independent of the brightness automatic/manual selector.

 // light_known/dark already arrive through the frame-coherent UI mailbox.

 // Hold through unknown samples; commit only in vertical blank. Reset = dark UI.

 reg light_theme;

 wire theme_blank=in_valid&&!in_de&&in_y>=12'd720;

 always @(posedge clk or negedge rst_n)begin

  if(!rst_n)light_theme<=1'b0;

  else if(theme_blank&&light_known)light_theme<=!dark;

 end







 // Palette selection changes chrome only. Video/photo pixels retain the

 // existing brightness/contrast pipeline and are never inverted or double-dimmed.

 function [23:0] light_palette;

  input [23:0] color;

  input foreground;

  input [11:0] px,py;

  reg badge;

  begin

   badge=px>=44&&px<196&&((py>=152&&py<215)||(py>=329&&py<392));

   case(color)

    24'h0c1826:light_palette=foreground?24'h203448:24'hf3f2ed;

    24'h102030:light_palette=24'hf3f2ed;

    24'h142a3c,24'h15394d:light_palette=24'hfcfcfa;

    24'h183a4b,24'h24364a:light_palette=24'he6edf2;

    24'h0b2538:light_palette=24'hedf2f5;

    24'hf1f5f9,24'hffffff:light_palette=badge&&py>=313?24'h246d67:24'h203448;

    24'h92a7b8:light_palette=24'h607081;

    24'h536d83:light_palette=24'ha8b5c1;

    24'hffbc66:light_palette=24'ha76017;

    24'h28c8ad:light_palette=foreground?24'h246d67:

      badge?(py<313?24'hdce9f7:24'hdceee8):24'h299b8e;

    24'h168ba0:light_palette=24'hdceee8;

    24'h28bd9c:light_palette=24'h299b8e;

    24'h20ddb0:light_palette=24'h159bc7;

    default:light_palette=color;

   endcase

  end

 endfunction

  function [3:0] base_event_code;
   input [25:0] events;
   begin
    base_event_code=4'd0;
    if(events[0])base_event_code=4'd1;
    if(events[1])base_event_code=4'd0;
    if(events[2])base_event_code=4'd2;
    if(events[3])base_event_code=4'd3;
    if(events[4])base_event_code=4'd4;
    if(events[5])base_event_code=4'd5;
    if(events[6])base_event_code=4'd6;
    if(events[7])base_event_code=4'd7;
    if(events[8])base_event_code=4'd8;
    if(events[9])base_event_code=4'd8;
    if(events[10])base_event_code=4'd9;
    if(events[11])base_event_code=4'd1;
    if(events[12])base_event_code=4'd10;
    if(events[13])base_event_code=4'd0;
    if(events[14])base_event_code=4'd11;
    if(events[15])base_event_code=4'd12;
    if(events[16])base_event_code=4'd13;
    if(events[17])base_event_code=4'd12;
    if(events[18])base_event_code=4'd14;
    if(events[19])base_event_code=4'd15;
    if(events[20])base_event_code=4'd15;
    if(events[21])base_event_code=4'd15;
    if(events[22])base_event_code=4'd12;
    if(events[23])base_event_code=4'd15;
    if(events[24])base_event_code=4'd10;
    if(events[25])base_event_code=4'd0;
   end
  endfunction

 // Internal static-base code only; media/foreground/FFT retain fullRGB.
 function [23:0] base_code_rgb;
 input [3:0] code;input theme;input [11:0] px,py;reg badge;
 begin
  badge=px>=44&&px<196&&((py>=152&&py<215)||(py>=329&&py<392));
  case(code)
   4'd0:base_code_rgb=theme?(24'h000000):24'h000000;
   4'd1:base_code_rgb=theme?(24'hf3f2ed):24'h102030;
   4'd2:base_code_rgb=theme?(24'hfcfcfa):24'h15394d;
   4'd3:base_code_rgb=theme?(24'he6edf2):24'h183a4b;
   4'd4:base_code_rgb=theme?(24'h299b8e):24'h28bd9c;
   4'd5:base_code_rgb=theme?(badge&&py>=313?24'h246d67:24'h203448):24'hffffff;
   4'd6:base_code_rgb=theme?(24'h432513):24'h432513;
   4'd7:base_code_rgb=theme?(24'h9c1820):24'h9c1820;
   4'd8:base_code_rgb=theme?(24'hfff0b0):24'hfff0b0;
   4'd9:base_code_rgb=theme?(24'h701018):24'h701018;
   4'd10:base_code_rgb=theme?(24'he6edf2):24'h24364a;
   4'd11:base_code_rgb=theme?(24'hf3f2ed):24'h0c1826;
   4'd12:base_code_rgb=theme?(badge?(py<313?24'hdce9f7:24'hdceee8):24'h299b8e):24'h28c8ad;
   4'd13:base_code_rgb=theme?(24'hfcfcfa):24'h142a3c;
   4'd14:base_code_rgb=theme?(24'hdceee8):24'h168ba0;
   4'd15:base_code_rgb=theme?(24'ha8b5c1):24'h536d83;
   default:base_code_rgb=24'd0;
  endcase
 end endfunction

 // Apply signed UI brightness with saturation, separately from theme choice.

 // This makes a paper-white night UI obey the same -64 target as media pixels.

 function [7:0] theme_dim;

  input [7:0] color;input signed [7:0] offset;

  reg signed [9:0] adjusted;

  begin

   adjusted=$signed({2'b00,color})+$signed({{2{offset[7]}},offset});

   theme_dim=adjusted<0?8'd0:adjusted>255?8'd255:adjusted[7:0];

  end

 endfunction









 // FFT panel20261030: all per-band envelope/peak work occurs in blank.

 // A: column ROM + gradient. B: state RAM read. C: short height/cap mux.

 // Three public pixel stages, no extra CDC, no random levels.

 // UI mailbox commits only at y>=720. Start at active frame origin;

 // all64update clocks finish in the header row, before any FFT pixels.

 wire panel_frame_tick=in_valid&&in_de&&in_x==0&&in_y==0&&!service_origin_seen;

 assign spectrum_frame_tick=panel_frame_tick;

 reg [5:0] fft_x_q;reg [23:0] b_rgb;

 wire [6:0] panel_bar,panel_peak;wire panel_ready,panel_busy;

 station_spectrum_panel_state #(.SNAPSHOT_INPUT(0),.STREAM_INPUT(STREAM_SPECTRUM),.PIXEL_HEIGHT_INPUT(PIXEL_HEIGHT_SPECTRUM)) panel_state(.clk(clk),.rst_n(rst_n),.frame_tick(panel_frame_tick),.raw_levels(levels),.stream_level(spectrum_stream_level),.stream_address(spectrum_stream_address),

  .read_bin(fft_x_q[4:0]),.pixel_bar(panel_bar),.pixel_peak(panel_peak),.ready(panel_ready),.busy(panel_busy),.frames(),.busy_frame_ticks());

 function [23:0] panel_blue;

  input [3:0] step;

  begin case(step)

   0:panel_blue=24'h087db8;1:panel_blue=24'h0d85be;2:panel_blue=24'h128cc4;

   3:panel_blue=24'h1794ca;4:panel_blue=24'h1c9bd0;5:panel_blue=24'h21a3d6;

   6:panel_blue=24'h27aadc;7:panel_blue=24'h2cb2e2;8:panel_blue=24'h31b9e8;

   9:panel_blue=24'h36c1ee;10:panel_blue=24'h3bc8f4;11:panel_blue=24'h40d0fa;

   default:panel_blue=24'h47d8ff;

  endcase end

 endfunction

 function [23:0] panel_dim;

  input [23:0] color;input signed [7:0] offset;

  begin panel_dim={theme_dim(color[23:16],offset),theme_dim(color[15:8],offset),theme_dim(color[7:0],offset)};end

 endfunction

 wire [11:0] panel_distance=service_ui?12'd650-in_y:12'd576-in_y;

 reg [8:0] a_panel_distance,b_panel_distance;
 // Equivalent cap bounds computed before the state-RAM output selection.
 reg [8:0] b_cap_upper,b_cap_lower;

 reg [23:0] a_panel_blue,b_panel_blue,b_panel_cap;

 reg b_panel_window,b_panel_column;

 wire panel_bar_pixel=b_panel_distance!=0&&b_panel_distance<={2'b00,panel_bar};

 wire panel_cap_pixel=panel_peak!=0&&{2'b00,panel_peak}<=b_cap_upper&&{2'b00,panel_peak}>=b_cap_lower;

 wire [23:0] panel_pixel_rgb=b_panel_column&&panel_cap_pixel?b_panel_cap:

  b_panel_column&&panel_bar_pixel?b_panel_blue:b_rgb;



 // Timing20261028r2: disjoint static text uses balanced OR selection.

 wire st_0=in_x>=34&&in_x<66&&in_y>=26&&in_y<58;

 wire [8:0] st_tx_0=in_x[8:0]-9'd34;

 wire [4:0] st_ty_0=in_y[4:0]-5'd26;

 wire st_1=in_x>=96&&in_x<352&&in_y>=26&&in_y<58;

 wire [8:0] st_tx_1=in_x[8:0]-9'd96;

 wire [4:0] st_ty_1=in_y[4:0]-5'd26;

 wire st_2=in_x>=1152&&in_x<1216&&in_y>=36&&in_y<52;

 wire [8:0] st_tx_2=in_x[8:0]-9'd128;

 wire [4:0] st_ty_2=in_y[4:0]-5'd4;

 wire st_3=in_x>=32&&in_x<256&&in_y>=96&&in_y<128;

 wire [8:0] st_tx_3=in_x[8:0]-9'd32;

 wire [4:0] st_ty_3=in_y[4:0]-5'd0;

 wire st_4=in_x>=1184&&in_x<1248&&in_y>=104&&in_y<120;

 wire [8:0] st_tx_4=in_x[8:0]-9'd160;

 wire [4:0] st_ty_4=in_y[4:0]-5'd8;

 wire st_5=in_x>=72&&in_x<168&&in_y>=168&&in_y<200;

 wire [8:0] st_tx_5=in_x[8:0]-9'd72;

 wire [4:0] st_ty_5=in_y[4:0]-5'd8;

 wire st_6=in_x>=224&&in_x<384&&in_y>=152&&in_y<184;

 wire [8:0] st_tx_6=in_x[8:0]-9'd224;

 wire [4:0] st_ty_6=in_y[4:0]-5'd24;

 wire st_7=in_x>=224&&in_x<352&&in_y>=196&&in_y<212;

 wire [8:0] st_tx_7=in_x[8:0]-9'd224;

 wire [4:0] st_ty_7=in_y[4:0]-5'd4;

 wire st_8=in_x>=1104&&in_x<1168&&in_y>=176&&in_y<192;

 wire [8:0] st_tx_8=in_x[8:0]-9'd80;

 wire [4:0] st_ty_8=in_y[4:0]-5'd16;

 wire st_9=in_x>=88&&in_x<136&&in_y>=271&&in_y<287;

 wire [8:0] st_tx_9=in_x[8:0]-9'd88;

 wire [4:0] st_ty_9=in_y[4:0]-5'd15;

 wire st_10=in_x>=352&&in_x<400&&in_y>=271&&in_y<287;

 wire [8:0] st_tx_10=in_x[8:0]-9'd352;

 wire [4:0] st_ty_10=in_y[4:0]-5'd15;

 wire st_11=in_x>=616&&in_x<664&&in_y>=271&&in_y<287;

 wire [8:0] st_tx_11=in_x[8:0]-9'd104;

 wire [4:0] st_ty_11=in_y[4:0]-5'd15;

 wire st_12=in_x>=880&&in_x<928&&in_y>=271&&in_y<287;

 wire [8:0] st_tx_12=in_x[8:0]-9'd368;

 wire [4:0] st_ty_12=in_y[4:0]-5'd15;

 wire st_13=in_x>=1144&&in_x<1192&&in_y>=271&&in_y<287;

 wire [8:0] st_tx_13=in_x[8:0]-9'd120;

 wire [4:0] st_ty_13=in_y[4:0]-5'd15;

 wire st_14=in_x>=72&&in_x<168&&in_y>=345&&in_y<377;

 wire [8:0] st_tx_14=in_x[8:0]-9'd72;

 wire [4:0] st_ty_14=in_y[4:0]-5'd25;

 wire st_15=in_x>=224&&in_x<416&&in_y>=329&&in_y<361;

 wire [8:0] st_tx_15=in_x[8:0]-9'd224;

 wire [4:0] st_ty_15=in_y[4:0]-5'd9;

 wire st_16=in_x>=224&&in_x<352&&in_y>=373&&in_y<389;

 wire [8:0] st_tx_16=in_x[8:0]-9'd224;

 wire [4:0] st_ty_16=in_y[4:0]-5'd21;

 wire st_17=in_x>=1104&&in_x<1168&&in_y>=353&&in_y<369;

 wire [8:0] st_tx_17=in_x[8:0]-9'd80;

 wire [4:0] st_ty_17=in_y[4:0]-5'd1;

 wire st_18=in_x>=88&&in_x<136&&in_y>=448&&in_y<464;

 wire [8:0] st_tx_18=in_x[8:0]-9'd88;

 wire [4:0] st_ty_18=in_y[4:0]-5'd0;

 wire st_19=in_x>=352&&in_x<400&&in_y>=448&&in_y<464;

 wire [8:0] st_tx_19=in_x[8:0]-9'd352;

 wire [4:0] st_ty_19=in_y[4:0]-5'd0;

 wire st_20=in_x>=616&&in_x<664&&in_y>=448&&in_y<464;

 wire [8:0] st_tx_20=in_x[8:0]-9'd104;

 wire [4:0] st_ty_20=in_y[4:0]-5'd0;

 wire st_21=in_x>=872&&in_x<936&&in_y>=448&&in_y<464;

 wire [8:0] st_tx_21=in_x[8:0]-9'd360;

 wire [4:0] st_ty_21=in_y[4:0]-5'd0;

 wire st_22=in_x>=1136&&in_x<1200&&in_y>=448&&in_y<464;

 wire [8:0] st_tx_22=in_x[8:0]-9'd112;

 wire [4:0] st_ty_22=in_y[4:0]-5'd0;

 wire st_23=in_x>=48&&in_x<176&&in_y>=504&&in_y<536;

 wire [8:0] st_tx_23=in_x[8:0]-9'd48;

 wire [4:0] st_ty_23=in_y[4:0]-5'd24;

 wire st_24=in_x>=1152&&in_x<1232&&in_y>=512&&in_y<528;

 wire [8:0] st_tx_24=in_x[8:0]-9'd128;

 wire [4:0] st_ty_24=in_y[4:0]-5'd0;

 wire st_25=in_x>=32&&in_x<192&&in_y>=688&&in_y<704;

 wire [8:0] st_tx_25=in_x[8:0]-9'd32;

 wire [4:0] st_ty_25=in_y[4:0]-5'd16;

 wire st_26=in_x>=1032&&in_x<1256&&in_y>=688&&in_y<704;

 wire [8:0] st_tx_26=in_x[8:0]-9'd8;

 wire [4:0] st_ty_26=in_y[4:0]-5'd16;

 wire st_enable=st_0|st_1|st_2|st_3|st_4|st_5|st_6|st_7|st_8|st_9|st_10|st_11|st_12|st_13|st_14|st_15|st_16|st_17|st_18|st_19|st_20|st_21|st_22|st_23|st_24|st_25|st_26;

 wire [5:0] st_label=(st_0?6'd51:6'd0)|

  (st_1?6'd32:6'd0)|

  (st_2?6'd1:6'd0)|

  (st_3?6'd33:6'd0)|

  (st_4?6'd2:6'd0)|

  (st_5?6'd34:6'd0)|

  (st_6?6'd36:6'd0)|

  (st_7?6'd38:6'd0)|

  (st_8?6'd25:6'd0)|

  (st_9?6'd39:6'd0)|

  (st_10?6'd40:6'd0)|

  (st_11?6'd41:6'd0)|

  (st_12?6'd42:6'd0)|

  (st_13?6'd43:6'd0)|

  (st_14?6'd35:6'd0)|

  (st_15?6'd37:6'd0)|

  (st_16?6'd38:6'd0)|

  (st_17?6'd25:6'd0)|

  (st_18?6'd39:6'd0)|

  (st_19?6'd44:6'd0)|

  (st_20?6'd41:6'd0)|

  (st_21?6'd45:6'd0)|

  (st_22?6'd46:6'd0)|

  (st_23?6'd47:6'd0)|

  (st_24?6'd50:6'd0)|

  (st_25?6'd7:6'd0)|

  (st_26?6'd49:6'd0);

 wire [4:0] st_column=(st_0?{1'b0,st_tx_0[8:5]}:5'd0)|

  (st_1?{1'b0,st_tx_1[8:5]}:5'd0)|

  (st_2?st_tx_2[8:4]:5'd0)|

  (st_3?{1'b0,st_tx_3[8:5]}:5'd0)|

  (st_4?st_tx_4[8:4]:5'd0)|

  (st_5?{1'b0,st_tx_5[8:5]}:5'd0)|

  (st_6?{1'b0,st_tx_6[8:5]}:5'd0)|

  (st_7?st_tx_7[8:4]:5'd0)|

  (st_8?st_tx_8[8:4]:5'd0)|

  (st_9?st_tx_9[8:4]:5'd0)|

  (st_10?st_tx_10[8:4]:5'd0)|

  (st_11?st_tx_11[8:4]:5'd0)|

  (st_12?st_tx_12[8:4]:5'd0)|

  (st_13?st_tx_13[8:4]:5'd0)|

  (st_14?{1'b0,st_tx_14[8:5]}:5'd0)|

  (st_15?{1'b0,st_tx_15[8:5]}:5'd0)|

  (st_16?st_tx_16[8:4]:5'd0)|

  (st_17?st_tx_17[8:4]:5'd0)|

  (st_18?st_tx_18[8:4]:5'd0)|

  (st_19?st_tx_19[8:4]:5'd0)|

  (st_20?st_tx_20[8:4]:5'd0)|

  (st_21?st_tx_21[8:4]:5'd0)|

  (st_22?st_tx_22[8:4]:5'd0)|

  (st_23?{1'b0,st_tx_23[8:5]}:5'd0)|

  (st_24?st_tx_24[8:4]:5'd0)|

  (st_25?st_tx_25[8:4]:5'd0)|

  (st_26?st_tx_26[8:4]:5'd0);

 wire [3:0] st_gx=(st_0?st_tx_0[4:1]:4'd0)|

  (st_1?st_tx_1[4:1]:4'd0)|

  (st_2?st_tx_2[3:0]:4'd0)|

  (st_3?st_tx_3[4:1]:4'd0)|

  (st_4?st_tx_4[3:0]:4'd0)|

  (st_5?st_tx_5[4:1]:4'd0)|

  (st_6?st_tx_6[4:1]:4'd0)|

  (st_7?st_tx_7[3:0]:4'd0)|

  (st_8?st_tx_8[3:0]:4'd0)|

  (st_9?st_tx_9[3:0]:4'd0)|

  (st_10?st_tx_10[3:0]:4'd0)|

  (st_11?st_tx_11[3:0]:4'd0)|

  (st_12?st_tx_12[3:0]:4'd0)|

  (st_13?st_tx_13[3:0]:4'd0)|

  (st_14?st_tx_14[4:1]:4'd0)|

  (st_15?st_tx_15[4:1]:4'd0)|

  (st_16?st_tx_16[3:0]:4'd0)|

  (st_17?st_tx_17[3:0]:4'd0)|

  (st_18?st_tx_18[3:0]:4'd0)|

  (st_19?st_tx_19[3:0]:4'd0)|

  (st_20?st_tx_20[3:0]:4'd0)|

  (st_21?st_tx_21[3:0]:4'd0)|

  (st_22?st_tx_22[3:0]:4'd0)|

  (st_23?st_tx_23[4:1]:4'd0)|

  (st_24?st_tx_24[3:0]:4'd0)|

  (st_25?st_tx_25[3:0]:4'd0)|

  (st_26?st_tx_26[3:0]:4'd0);

 wire [3:0] st_gy=(st_0?st_ty_0[4:1]:4'd0)|

  (st_1?st_ty_1[4:1]:4'd0)|

  (st_2?st_ty_2[3:0]:4'd0)|

  (st_3?st_ty_3[4:1]:4'd0)|

  (st_4?st_ty_4[3:0]:4'd0)|

  (st_5?st_ty_5[4:1]:4'd0)|

  (st_6?st_ty_6[4:1]:4'd0)|

  (st_7?st_ty_7[3:0]:4'd0)|

  (st_8?st_ty_8[3:0]:4'd0)|

  (st_9?st_ty_9[3:0]:4'd0)|

  (st_10?st_ty_10[3:0]:4'd0)|

  (st_11?st_ty_11[3:0]:4'd0)|

  (st_12?st_ty_12[3:0]:4'd0)|

  (st_13?st_ty_13[3:0]:4'd0)|

  (st_14?st_ty_14[4:1]:4'd0)|

  (st_15?st_ty_15[4:1]:4'd0)|

  (st_16?st_ty_16[3:0]:4'd0)|

  (st_17?st_ty_17[3:0]:4'd0)|

  (st_18?st_ty_18[3:0]:4'd0)|

  (st_19?st_ty_19[3:0]:4'd0)|

  (st_20?st_ty_20[3:0]:4'd0)|

  (st_21?st_ty_21[3:0]:4'd0)|

  (st_22?st_ty_22[3:0]:4'd0)|

  (st_23?st_ty_23[4:1]:4'd0)|

  (st_24?st_ty_24[3:0]:4'd0)|

  (st_25?st_ty_25[3:0]:4'd0)|

  (st_26?st_ty_26[3:0]:4'd0);

 wire [23:0] st_color=(st_0?24'h0c1826:24'd0)|

  (st_1?24'hf1f5f9:24'd0)|

  (st_2?24'h92a7b8:24'd0)|

  (st_3?24'hf1f5f9:24'd0)|

  (st_4?24'h92a7b8:24'd0)|

  (st_5?24'h0c1826:24'd0)|

  (st_6?24'hf1f5f9:24'd0)|

  (st_7?24'h28c8ad:24'd0)|

  (st_8?24'hf1f5f9:24'd0)|

  (st_9?24'hf1f5f9:24'd0)|

  (st_10?24'hf1f5f9:24'd0)|

  (st_11?24'h28c8ad:24'd0)|

  (st_12?24'hf1f5f9:24'd0)|

  (st_13?24'hf1f5f9:24'd0)|

  (st_14?24'hf1f5f9:24'd0)|

  (st_15?24'hf1f5f9:24'd0)|

  (st_16?24'h28c8ad:24'd0)|

  (st_17?24'hf1f5f9:24'd0)|

  (st_18?24'hf1f5f9:24'd0)|

  (st_19?24'hf1f5f9:24'd0)|

  (st_20?24'h28c8ad:24'd0)|

  (st_21?24'hf1f5f9:24'd0)|

  (st_22?24'hf1f5f9:24'd0)|

  (st_23?24'hf1f5f9:24'd0)|

  (st_24?24'h92a7b8:24'd0)|

  (st_25?24'h92a7b8:24'd0)|

  (st_26?24'h92a7b8:24'd0);

 wire st_minute=in_x>=1024&&in_x<1088&&((in_y>=148&&in_y<212)||(in_y>=325&&in_y<389));

 wire st_menu=menu!=0&&in_y>=672&&in_y<704&&in_x>=64&&in_x<640;

 wire st_menu_numeric=in_x>=224&&in_x<352&&menu!=4&&menu!=6;





 // Timing20261028r3: static text glyphs read in A alongside legacy text ROM.

 wire [3:0] service_text_band=((in_y>=12'd80&&in_y<13'd136)?4'd1:4'd0)|

  ((in_y>=12'd136&&in_y<13'd192)?4'd2:4'd0)|

  ((in_y>=12'd192&&in_y<13'd240)?4'd3:4'd0)|

  ((in_y>=12'd240&&in_y<13'd313)?4'd4:4'd0)|

  ((in_y>=12'd313&&in_y<13'd369)?4'd5:4'd0)|

  ((in_y>=12'd369&&in_y<13'd410)?4'd6:4'd0)|

  ((in_y>=12'd410&&in_y<13'd490)?4'd7:4'd0)|

  ((in_y>=12'd490&&in_y<13'd576)?4'd8:4'd0)|

  ((in_y>=12'd576&&in_y<13'd4096)?4'd9:4'd0);

 localparam [32767:0] SERVICE_GLYPH_BITS={

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060602222262634342f2fbaba4e4eb9b94a4a282835350d0db8b84040363660,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060600a0a16161d1d2e2e505041410808292927273e3e60606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060606060bdbd3434bcbcbbbb4f4f60606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060606060030303034d4d4d4d4141414108080808606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060606060acacabab444417176060606060606060606060606060,

 256'h60606060606060606060601212b7b7b6b6272760606060606060606060606060,

 256'h60606060606060606060606060a6a6a5a5a4a460606060606060606060606060,

 256'h60606060606060606060606060604040b5b5b4b4606060606060606060606060,

 256'h606060606060606060606060606060afafaeaeadad6060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060606060606060606060606060603535a6a6a5a5a4a451513535,

 256'h0000020260606060606060404040407272727270707070606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060606060606060606060606043430d0d48480c0c60606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060606060606060606060acacacacabababab4444444417171717a8a8a8a8,

 256'ha7a7a7a760606060606060404040407272727270707070606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060606060603535aaaaa9a9606060606060606060606060606060,

 256'h606060606060606060606060b2b2b3b307076060606060606060606060606060,

 256'h60606060606060606060606060a6a6a5a5a4a460606060606060606060606060,

 256'h6060606060606060606060606060b2b2b1b1b0b0606060606060606060606060,

 256'h606060606060606060606060606060afafaeaeadad6060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060606060606060606060606060603535a6a6a5a5a4a451513535,

 256'h0000020260606060606060404040407171717170707070606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060606060606060606060606043430d0d48480c0c60606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606035353535aaaaaaaaa9a9a9a9a8a8a8a8,

 256'ha7a7a7a760606060606060404040407171717170707070606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060600e0e2c2c171704046060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h35353535a6a6a6a6a5a5a5a5a4a4a4a45151515135353535a3a3a3a360606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h60606060606060602222262634342f2f60606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h6060606060606060606060606060606060606060606060606060606060606060,

 256'h606060606060606060606060606060606060606035353535050505050b0b0b0b,

 256'h1f1f1f1f2a2a2a2aa2a2a2a2a1a1a1a1a0a0a0a0606060a0a0a0a0a060606060

 };

 reg [7:0] service_glyph_rom[0:4095];reg [7:0] service_glyph_q;

 integer service_glyph_init;

 initial for(service_glyph_init=0;service_glyph_init<4096;service_glyph_init=service_glyph_init+1)

  service_glyph_rom[service_glyph_init]=SERVICE_GLYPH_BITS[service_glyph_init*8+:8];

 always @(posedge clk)service_glyph_q<=service_glyph_rom[{service_text_band,in_x[10:3]}];



 reg [23:0] text_rgb;reg [1:0] service_scale;

 integer service_ty;





 // A-stage synchronous ROM: {bar-column-active,bin[4:0]}.



 // Only the FFT window consumes this table. All coordinates above1023 are



 // rejected by full-width region checks before B-stage color selection.



 // Per-band comparisons capture the exact input-pixel snapshot, even if



 // callers change controls every clock. Public three-stage latency is unchanged.



 localparam [6143:0] FFT_X_BITS={



  256'h0000000000000000000000000000000000000000000000000000000000000000,



  256'h000000007df7df7df7fffffffffffffffffffffffffffffffffde79e79e79efb,



  256'hefbefbefbefbefbefbefbefbefbefbe75d75d75d77df7df7df7df7df7df7df7d,



  256'hf7df7df7df5c71c71c71cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3c6db6db6db6,



  256'hfbefbefbefbefbefbefbefbefbefbefbeda69a69a69aebaebaebaebaebaebaeb,



  256'haebaebaebaeba659659659679e79e79e79e79e79e79e79e79e79e79e58618618,



  256'h618e38e38e38e38e38e38e38e38e38e38e385d75d75d75f7df7df7df7df7df7d,



  256'hf7df7df7df7df7dd6596596596db6db6db6db6db6db6db6db6db6db6db655555,



  256'h5555575d75d75d75d75d75d75d75d75d75d75d54514514514d34d34d34d34d34,



  256'hd34d34d34d34d34d344d34d34d34f3cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3cd24,



  256'h92492492cb2cb2cb2cb2cb2cb2cb2cb2cb2cb2cb2451451451471c71c71c71c7,



  256'h1c71c71c71c71c71c71c50410410410c30c30c30c30c30c30c30c30c30c30c30,



  256'h3cf3cf3cf3efbefbefbefbefbefbefbefbefbefbefbce38e38e38ebaebaebaeb,



  256'haebaebaebaebaebaebaebae34d34d34d36db6db6db6db6db6db6db6db6db6db6,



  256'hdb4c30c30c30cb2cb2cb2cb2cb2cb2cb2cb2cb2cb2cb2c2cb2cb2cb2ebaebaeb,



  256'haebaebaebaebaebaebaebaebaca28a28a28aaaaaaaaaaaaaaaaaaaaaaaaaaaaa,



  256'haaaaa249249249269a69a69a69a69a69a69a69a69a69a69a48208208208a28a2,



  256'h8a28a28a28a28a28a28a28a28a281c71c71c71e79e79e79e79e79e79e79e79e7,



  256'h9e79e79c61861861869a69a69a69a69a69a69a69a69a69a69a61451451451659,



  256'h6596596596596596596596596596594410410410492492492492492492492492,



  256'h49249249240c30c30c30e38e38e38e38e38e38e38e38e38e38e38c2082082082,



  256'h8a28a28a28a28a28a28a28a28a28a28a20410410410618618618618618618618,



  256'h6186186186184000000000082082082082082082082082082082082000000000,



  256'h0000000000000000000000000000000000000000000000000000000000000000};



 reg [5:0] fft_x_rom[0:1023];integer init_fft_x;



 initial for(init_fft_x=0;init_fft_x<1024;init_fft_x=init_fft_x+1)



  fft_x_rom[init_fft_x]=FFT_X_BITS[init_fft_x*6+:6];





 // Same32FFT bins, widened horizontally in the approved music panel.

 localparam [12287:0] SERVICE_FFT_X_BITS={

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000,

  256'h000000007df7df7df7df7ffffffffffffffffffffffffffffffffffffffffffd,

  256'he79e79e79e79efbefbefbefbefbefbefbefbefbefbefbefbefbefbe75d75d75d,

  256'h75d77df7df7df7df7df7df7df7df7df7df7df7df7df7df5c71c71c71c71cf3cf,

  256'h3cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3cf3c6db6db6db6db6fbefbefbefbef,

  256'hbefbefbefbefbefbefbefbefbefbeda69a69a69a69aebaebaebaebaebaebaeba,

  256'hebaebaebaebaebaebaeba659659659659679e79e79e79e79e79e79e79e79e79e,

  256'h79e79e79e79e58618618618618e38e38e38e38e38e38e38e38e38e38e38e38e3,

  256'h8e385d75d75d75d75f7df7df7df7df7df7df7df7df7df7df7df7df7df7dd6596,

  256'h596596596db6db6db6db6db6db6db6db6db6db6db6db6db6db65555555555555,

  256'h75d75d75d75d75d75d75d75d75d75d75d75d75d75d54514514514514d34d34d3,

  256'h4d34d34d34d34d34d34d34d34d34d34d344d34d34d34d34f3cf3cf3cf3cf3cf3,

  256'hcf3cf3cf3cf3cf3cf3cf3cf3cd2492492492492cb2cb2cb2cb2cb2cb2cb2cb2c,

  256'hb2cb2cb2cb2cb2cb2451451451451471c71c71c71c71c71c71c71c71c71c71c7,

  256'h1c71c71c50410410410410c30c30c30c30c30c30c30c30c30c30c30c30c30c30,

  256'h3cf3cf3cf3cf3efbefbefbefbefbefbefbefbefbefbefbefbefbefbce38e38e3,

  256'h8e38ebaebaebaebaebaebaebaebaebaebaebaebaebaebae34d34d34d34d36db6,

  256'hdb6db6db6db6db6db6db6db6db6db6db6db6db4c30c30c30c30cb2cb2cb2cb2c,

  256'hb2cb2cb2cb2cb2cb2cb2cb2cb2cb2c2cb2cb2cb2cb2ebaebaebaebaebaebaeba,

  256'hebaebaebaebaebaebaebaca28a28a28a28aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,

  256'haaaaaaaaaaaaa249249249249269a69a69a69a69a69a69a69a69a69a69a69a69,

  256'ha69a48208208208208a28a28a28a28a28a28a28a28a28a28a28a28a28a281c71,

  256'hc71c71c71e79e79e79e79e79e79e79e79e79e79e79e79e79e79c618618618618,

  256'h69a69a69a69a69a69a69a69a69a69a69a69a69a69a6145145145145165965965,

  256'h9659659659659659659659659659659659441041041041049249249249249249,

  256'h249249249249249249249249240c30c30c30c30e38e38e38e38e38e38e38e38e,

  256'h38e38e38e38e38e38c20820820820828a28a28a28a28a28a28a28a28a28a28a2,

  256'h8a28a28a20410410410410618618618618618618618618618618618618618618,

  256'h4000000000000082082082082082082082082082082082082082082000000000,

  256'h0000000000000000000000000000000000000000000000000000000000000000

 };

 reg [5:0] service_fft_x_rom[0:2047];integer init_service_fft;

 initial for(init_service_fft=0;init_service_fft<2048;init_service_fft=init_service_fft+1)

  service_fft_x_rom[init_service_fft]=SERVICE_FFT_X_BITS[init_service_fft*6+:6];

 always @(posedge clk)fft_x_q<=service_ui?service_fft_x_rom[in_x[10:0]]:fft_x_rom[in_x[9:0]];





 wire fft_window=in_de&&(

  (service_ui&&in_x>=48&&in_x<1232&&in_y>=548&&in_y<650)||

  (((scene==0&&normal_media==1)||(scene==0&&menu==7))&&

   in_x>=48&&in_x<976&&in_y>=384&&in_y<592));

 wire menu_covers_fft=menu!=0&&scene==0&&in_y>=576&&in_y<608&&in_x>=64&&in_x<640;

 reg a_fft_window;reg [31:0] a_fft_bars; // retained reset-only compatibility name; not displayed



 // In the consumed window384<=y<576, 576-y is1..192. Modulo256



 // subtraction is exact there; the separate y<576 mask rejects zero and



 // wrapped differences below the baseline. Non-window values are unused.



 wire [7:0] fft_remaining=8'd64-in_y[7:0];







 // Consumed only inside96<=x<928, equivalent to (x-96)%200<24.



 // Every rendered text row starts at y multiple32, except header16 and



 // route labels240/400. Truncating (y-start)>>1 to4 bits therefore needs



 // only y[4:1], with its top bit inverted in those half-offset regions.



 // Route and arrival-side text can share a y range: preserve x/scene gating.



 wire font_half_offset=(in_y>=16&&in_y<48)||



  (scene==1&&!music_selected&&in_x>=64&&in_x<256&&



   ((in_y>=240&&in_y<272)||(in_y>=400&&in_y<432)));



 wire route_dot=(in_x<12'd120)||



  (in_x>=12'd296&&in_x<12'd320)||(in_x>=12'd496&&in_x<12'd520)||



  (in_x>=12'd696&&in_x<12'd720)||(in_x>=12'd896&&in_x<12'd920);



 // Numeric regions are disjoint, with the same menu priority as below.



 wire numeric_menu=menu!=0&&scene<2&&((service_ui&&in_y>=672&&in_y<704)||(!service_ui&&in_y>=576&&in_y<608))&&



  in_x>=224&&in_x<352&&menu!=4&&menu!=6;



 wire numeric_arrival1=scene==0&&in_y>=224&&in_y<256&&in_x>=1040&&in_x<1136;



 wire numeric_arrival2=scene==0&&in_y>=320&&in_y<352&&in_x>=1040&&in_x<1136;



 wire [8:0] brightness_magnitude=brightness[7]?



  (~{brightness[7],brightness}+9'd1):{1'b0,brightness};



 wire [8:0] selected_number=numeric_menu?



  (menu==1?brightness_magnitude:menu==2?contrast:(menu==3||menu==7)?{5'd0,volume}:{7'd0,transition}):



  numeric_arrival1?{1'b0,arrival1}:numeric_arrival2?{1'b0,arrival2}:9'd0;



 // ROM reads alongside text-ROM stageA; numeric glyph selection moves



 // to the font input at stageB. Sign/space and all other glyphs stay unchanged.



 localparam [6143:0] BCD_BITS=6144'h511510509508507506505504503502501500499498497496495494493492491490489488487486485484483482481480479478477476475474473472471470469468467466465464463462461460459458457456455454453452451450449448447446445444443442441440439438437436435434433432431430429428427426425424423422421420419418417416415414413412411410409408407406405404403402401400399398397396395394393392391390389388387386385384383382381380379378377376375374373372371370369368367366365364363362361360359358357356355354353352351350349348347346345344343342341340339338337336335334333332331330329328327326325324323322321320319318317316315314313312311310309308307306305304303302301300299298297296295294293292291290289288287286285284283282281280279278277276275274273272271270269268267266265264263262261260259258257256255254253252251250249248247246245244243242241240239238237236235234233232231230229228227226225224223222221220219218217216215214213212211210209208207206205204203202201200199198197196195194193192191190189188187186185184183182181180179178177176175174173172171170169168167166165164163162161160159158157156155154153152151150149148147146145144143142141140139138137136135134133132131130129128127126125124123122121120119118117116115114113112111110109108107106105104103102101100099098097096095094093092091090089088087086085084083082081080079078077076075074073072071070069068067066065064063062061060059058057056055054053052051050049048047046045044043042041040039038037036035034033032031030029028027026025024023022021020019018017016015014013012011010009008007006005004003002001000;



 reg [11:0] decimal_rom[0:511];reg [11:0] decimal_q;integer init_digit;



 initial for(init_digit=0;init_digit<512;init_digit=init_digit+1)



  decimal_rom[init_digit]=BCD_BITS[init_digit*12+:12];



 always @(posedge clk)decimal_q<=decimal_rom[selected_number];



 wire numeric_pixel=in_de&&((numeric_menu&&in_x>=256)||numeric_arrival1||numeric_arrival2);



 wire [1:0] numeric_digit=numeric_menu?((in_x-12'd256)>>5):((in_x-12'd1040)>>5);



 reg a_numeric;reg [1:0] a_digit;



 wire [3:0] decimal_digit=a_digit==0?decimal_q[11:8]:a_digit==1?decimal_q[7:4]:decimal_q[3:0];



 wire [7:0] decimal_glyph=8'd112+decimal_digit;



 function [7:0] effect;



  input [7:0] c;input signed [7:0] b;input [8:0] gain;



  // c-128 is -128..127; multiplying gain0..511 fits signed17 bits.



  // After arithmetic /256 plus128 and brightness-128..127, value fits11.



  reg signed [8:0] centered;reg signed [16:0] product;reg signed [10:0] value;



  begin centered=$signed({1'b0,c})-9'sd128;product=centered*$signed({1'b0,gain});



   value=(product>>>8)+11'sd128+b;effect=value<0?0:value>255?255:value[7:0];end



 endfunction



 // Products are sampled in A, finishing/saturation in B. Products fit



 // signed17 bits (-65408..64897); the final signed11-bit value fits exactly.



 // Product registers need no reset: a_media_effect resets low, and each true



 // flag travels beside products from the same input cycle. No pixel latency



 // or reset change at the public outputs, and no additional frame storage.



 function signed [16:0] color_product;input [7:0] c;input [8:0] gain;



  reg signed [8:0] centered;



  begin centered=$signed({1'b0,c})-9'sd128;color_product=centered*$signed({1'b0,gain});end



 endfunction



 function [7:0] finish_color;input signed [16:0] p;input signed [7:0] b;



  reg signed [10:0] value;



  begin value=(p>>>8)+11'sd128+b;finish_color=value<0?0:value>255?255:value[7:0];end



 endfunction



 reg signed [16:0] a_product_r,a_product_g,a_product_b;



 reg signed [7:0] a_effect_brightness;reg a_media_effect;



 wire media_effect=in_de&&scene==0&&in_x>=32&&in_x<992&&in_y>=72&&in_y<612&&



  !(menu!=0&&in_y>=576&&in_y<608&&in_x>=64&&in_x<640);



 always @(posedge clk)begin



  a_product_r<=color_product(media_rgb[23:16],contrast);



  a_product_g<=color_product(media_rgb[15:8],contrast);



  a_product_b<=color_product(media_rgb[7:0],contrast);



  a_effect_brightness<=brightness;



 end



 // Text enable is the union of regions whose original priority branches

 // all set text_enable=1. Glyph/label selection keeps its original priority.

 wire parallel_text_enable=in_de&&(

  (in_y>=16&&in_y<48&&((in_x>=32&&in_x<512)||(in_x>=1024&&in_x<1248)))||

  (in_y>=96&&in_y<128&&in_x>=64&&in_x<992)||

  (scene==1&&in_y>=160&&in_y<192&&in_x>=64&&in_x<992)||

  (scene>=2&&in_y>=224&&in_y<256&&in_x>=64&&in_x<1088)||

  (scene==2&&in_y>=320&&in_y<352&&in_x>=64&&in_x<512)||

  (scene==1&&!music_selected&&in_x>=64&&in_x<256&&

   ((in_y>=240&&in_y<272)||(in_y>=400&&in_y<432)))||

  (scene<2&&in_x>=1040&&in_x<1248&&

   ((in_y>=160&&in_y<192)||(in_y>=448&&in_y<480)||(light_known&&in_y>=512&&in_y<544)))||

  (scene<2&&in_x>=1040&&in_x<1136&&

   ((in_y>=224&&in_y<256)||(in_y>=320&&in_y<352)))||

  (in_y>=640&&in_y<672&&in_x>=32&&in_x<1248)||

  (scene<2&&menu!=0&&in_y>=576&&in_y<608&&in_x>=64&&in_x<640));

 // gx consumes only tx[4:1]. All label origins are multiples of32 except

 // arrival-side1040 (half-cell16 offset); scrolling consumes modulo32 sum.

 // Values outside enabled text are unused by public pixels, so do not put

 // the old long label-priority chain back on the coordinate path.

 wire font_side_half=scene<2&&in_x>=1040&&in_x<1248&&

  ((in_y>=160&&in_y<192)||(in_y>=224&&in_y<256)||(in_y>=320&&in_y<352)||

   (in_y>=448&&in_y<480)||(in_y>=512&&in_y<544));

 wire font_scrolling=in_y>=640&&in_y<672&&in_x>=32&&in_x<1248;

 wire [4:0] font_scroll_sum=in_x[4:0]+scroll[4:0];

 wire [3:0] fast_gx=font_scrolling?font_scroll_sum[4:1]:{in_x[4]^font_side_half,in_x[3:1]};



 always @*begin



  base_events=0; begin base_events[0] = 1'b1; end text_enable=0;label_id=0;column=0;gx=0;gy=0;direct=0;direct_glyph=96;



  tx=0;number=0;text_rgb=24'hffffff;service_scale=1;service_ty=0;



  if(in_x>=32&&in_x<992&&in_y>=72&&in_y<612)begin



   if(scene==0)begin base_events[1] = 1'b1; end  // Deferred media effect is selected in B.



   else if(scene==1)begin base_events[2] = 1'b1; end 



  end



  if(in_x>=1024&&in_x<1248&&in_y>=72&&in_y<612)begin base_events[3] = 1'b1; end 



  if(scene==1&&!music_selected)begin



   if(in_x>=96&&in_x<928&&((in_y>=300&&in_y<308)||(in_y>=460&&in_y<468)))begin base_events[4] = 1'b1; end 



   if(in_x>=96&&in_x<928&&route_dot&&



     ((in_y>=292&&in_y<316)||(in_y>=452&&in_y<476)))begin base_events[5] = 1'b1; end 



  end



  if(scene==2)begin base_events[6] = 1'b1; end 



  if(scene==3)begin



   begin base_events[7] = 1'b1; end 



   if(in_x>=1100&&in_x<1180&&in_y>=120&&in_y<240)begin base_events[8] = 1'b1; end 



   if(in_x>=1100&&in_x<1180&&in_y>=264&&in_y<300)begin base_events[9] = 1'b1; end 



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



  else if(scene==2&&in_y>=320&&in_y<352&&in_x>=64&&in_x<512)begin



   // ASCII glyphs use the SAME synchronous font ROM/pixel pipeline.



   // E:dd C:dd S:d = coordinator error, first fault cause, current phase.



   text_enable=1;direct=1;tx=in_x-64;gy=(in_y-320)>>1;



   case((in_x-64)>>5)



    0:direct_glyph=133;1:direct_glyph=122;



    2:direct_glyph=112+(recovery_status[10:7]>=10?1:0);



    3:direct_glyph=112+(recovery_status[10:7]>=10?recovery_status[10:7]-10:recovery_status[10:7]);



    5:direct_glyph=131;6:direct_glyph=122;



    7:direct_glyph=112+(recovery_status[6:3]>=10?1:0);



    8:direct_glyph=112+(recovery_status[6:3]>=10?recovery_status[6:3]-10:recovery_status[6:3]);



    10:direct_glyph=147;11:direct_glyph=122;12:direct_glyph=112+recovery_status[2:0];



    default:direct_glyph=96;



   endcase



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



   number=arrival1;direct_glyph=8'd112;



  end



  else if(scene<2&&in_y>=320&&in_y<352&&in_x>=1040&&in_x<1136)begin



   text_enable=1;direct=1;tx=in_x-1040;gy=(in_y-320)>>1;



   number=arrival2;direct_glyph=8'd112;



  end



  else if(scene<2&&in_y>=448&&in_y<480&&in_x>=1040&&in_x<1248)begin



   text_enable=1;label_id=auto_brightness?14:15;tx=in_x-1040;gy=(in_y-448)>>1;



  end



  else if(scene<2&&in_y>=512&&in_y<544&&in_x>=1040&&in_x<1248&&light_known)begin



   text_enable=1;label_id=dark?29:28;tx=in_x-1040;gy=(in_y-512)>>1;



  end



  else if(in_y>=640&&in_y<672&&in_x>=32&&in_x<1248)begin



   begin base_events[10] = (scene==3); base_events[11] = !(scene==3); end text_enable=1;label_id=scene==3?9:7;



   tx=in_x-32+scroll;gy=(in_y-640)>>1;



  end



  // Parameter menu replaces a bounded strip; values are committed inputs only.



  if(menu!=0&&scene<2&&in_y>=576&&in_y<608&&in_x>=64&&in_x<640)begin



   begin base_events[12] = 1'b1; end text_enable=1;direct=0;tx=in_x-64;gy=(in_y-576)>>1;



   case(menu)1:label_id=16;2:label_id=17;3:label_id=13;4:label_id=normal_media==0?19:normal_media==1?20:18;5:label_id=21;default:label_id=22;endcase



   // Existing ASCII ROM: "1KHZ", followed by effective volume digits.

   if(menu==7&&in_x<224)begin

    direct=1;

    case((in_x-64)>>5)

     0:direct_glyph=113;1:direct_glyph=139;2:direct_glyph=136;3:direct_glyph=154;

     default:direct_glyph=96;

    endcase

   end

   if(in_x>=224&&in_x<352&&menu!=4&&menu!=6)begin



    direct=1;tx=in_x-224;



    case(menu)1:number=brightness[7]?-brightness:brightness;2:number=contrast;3,7:number=volume;default:number=transition;endcase



    if(in_x<256)direct_glyph=menu==1&&brightness[7]?109:96;



    else direct_glyph=8'd112;



   end



  end



  // This final assignment bypasses earlier label-priority row selection.



  // Row values outside enabled text do not affect any public pixel output.



  gy={in_y[4]^font_half_offset,in_y[3:1]};



  column=(tx>>5)&31;gx=(tx>>1)&15;



  if(!in_de)begin begin base_events[13] = 1'b1; end text_enable=0;end



  if(service_ui)begin

   begin base_events[14] = 1'b1; end text_enable=0;direct=0;label_id=0;tx=0;gy=0;

   service_scale=1;service_ty=0;text_rgb=24'hf1f5f9;

   if(in_x>=24&&in_x<76&&in_y>=18&&in_y<66)begin base_events[15] = 1'b1; end 

   if(in_x>=24&&in_x<1256&&

    ((in_y>=136&&in_y<301)||(in_y>=313&&in_y<478)||(in_y>=490&&in_y<665)))begin base_events[16] = 1'b1; end 

   if(in_x>=44&&in_x<196&&((in_y>=152&&in_y<215)||(in_y>=329&&in_y<392)))

    begin base_events[17] = (in_y<313); base_events[18] = !(in_y<313); end 

   if(in_x>=24&&in_x<1256&&((in_y>=82&&in_y<84)||(in_y>=678&&in_y<680)))begin base_events[19] = 1'b1; end 

   if(in_x>=1124&&in_x<1256&&in_y>=24&&in_y<64&&

    (in_x<1126||in_x>=1254||in_y<26||in_y>=62))begin base_events[20] = 1'b1; end 

   if(in_x>=982&&in_x<984&&((in_y>=154&&in_y<217)||(in_y>=331&&in_y<394)))begin base_events[21] = 1'b1; end 

   if(in_x>=112&&in_x<=1168&&((in_y>=246&&in_y<250)||(in_y>=423&&in_y<427)))

    begin base_events[22] = (in_x<376); base_events[23] = !(in_x<376); end 

   // Circle color is selected in C after its B-stage mask ROM.

   text_enable=st_enable;label_id=0;column=0;gx=st_gx;gy=st_gy;

   text_rgb=st_color;direct_glyph=96;



   // Fixed preset minutes: one large digit, no leading zeros/countdown.

   if(st_minute)begin

    text_enable=1;direct=1;direct_glyph=in_y<313?8'd115:8'd117;

    tx=in_x-1024;service_ty=in_y<313?in_y-148:in_y-325;service_scale=2;

    text_rgb=in_y<313?24'hffbc66:24'hf1f5f9;

   end

   // The existing parameter OSD remains available, moved below the music card.

   if(st_menu)begin

    begin base_events[24] = 1'b1; end text_enable=1;direct=0;tx=in_x-64;

    service_ty=in_y-672;service_scale=1;text_rgb=24'hffffff;

    case(menu)1:label_id=16;2:label_id=17;3:label_id=13;4:label_id=normal_media==0?19:normal_media==1?20:18;

     5:label_id=21;default:label_id=22;endcase

    if(menu==7&&in_x<224)begin

     direct=1;

     case((in_x-64)>>5)0:direct_glyph=113;1:direct_glyph=139;2:direct_glyph=136;3:direct_glyph=154;

      default:direct_glyph=96;endcase

    end

    if(in_x>=224&&in_x<352&&menu!=4&&menu!=6)begin

     direct=1;tx=in_x-224;

     if(in_x<256)direct_glyph=menu==1&&brightness[7]?109:96;

     else direct_glyph=112;

    end

   end

   if(st_menu)begin

    column=st_menu_numeric?in_x[9:5]-5'd7:in_x[9:5]-5'd2;

    gx=in_x[4:1];gy=in_y[4:1];

   end else if(st_minute)begin

    column=0;gx=in_x[5:2];gy=(service_ty>>2)&15;

   end

   if(!in_de)begin begin base_events[25] = 1'b1; end text_enable=0;end

  end





 end



 wire [7:0] rom_glyph;reg a_direct,a_text,a_valid,a_de,a_hs,a_vs;



 reg [23:0] a_text_rgb,b_text_rgb;reg a_service_ui,a_service_menu;

 reg [7:0] a_glyph;reg [3:0] a_gx,a_gy;reg [25:0] a_base_events;reg [11:0] a_x,a_y;



 wire ink;station_text_rom text_rom(.clk(clk),.label_id(label_id),.column(column),.glyph(rom_glyph));



 station_font_rom font_rom(.clk(clk),.glyph(a_numeric?decimal_glyph:(a_direct?a_glyph:(a_service_ui&&!a_service_menu?service_glyph_q:rom_glyph))),.x(a_gx),.y(a_gy),.ink(ink));



 reg b_text,b_valid,b_de,b_hs,b_vs;reg [11:0] b_x,b_y;

 wire final_foreground=b_text&&ink;

 // Timing20261030r6: independent base/foreground brightness paths.

 // Font ROM only controls the final mux; never a signed brightness carry chain.

 // Panel data selects after the nonpanel brightness arithmetic. No RAM

 // height/peak signal can feed a theme_dim adder in this cone.

 wire apply_base_theme=b_theme&&!b_theme_media&&!b_panel_window;

 // B already holds the four light-theme dot colors at this brightness.

 // The shape ROM controls only C-stage selection, never a brightness adder.

 wire [23:0] dot_light_rgb=!b_dot_shape[1]?

  (b_dot_target?(b_dot_blink?light_halo_b:light_muted_b):b_dot_past?light_teal_b:light_muted_b):

  (b_dot_past&&b_dot_shape[4]?light_teal_b:light_inner_b);

 wire [23:0] background_theme_rgb=b_theme&&!b_theme_media?

  {theme_dim(b_rgb[23:16],b_theme_brightness),theme_dim(b_rgb[15:8],b_theme_brightness),theme_dim(b_rgb[7:0],b_theme_brightness)}:b_rgb;

 wire [23:0] nonpanel_theme_rgb=dot_halo_overlay?

  (b_theme&&!b_theme_media?light_halo_b:(b_theme?24'ha76017:24'hffbc66)):

  dot_disk_overlay?(b_theme&&!b_theme_media?dot_light_rgb:dot_disk_rgb):background_theme_rgb;

 wire [23:0] panel_base_rgb=dot_halo_overlay?(b_theme?24'ha76017:24'hffbc66):dot_disk_overlay?dot_disk_rgb:panel_pixel_rgb;

 wire [23:0] base_theme_rgb=b_panel_window?panel_base_rgb:nonpanel_theme_rgb;

 wire [23:0] final_theme_rgb=final_foreground?b_text_rgb:base_theme_rgb;
 // Four-stage pixel contract: C independently registers panel shading,
 // nonpanel shading, overlays and font; D performs final priority selection.
 // All coordinates,valid,DE,HS,VS gain the SAME one pixel-clock latency.
 // No additional frame, line, audio or CDC state; raster period unchanged.
 reg c_valid,c_de,c_hs,c_vs;reg [11:0] c_x,c_y;
 reg c_panel_window,c_panel_overlay,c_foreground;
 reg [23:0] c_panel_rgb,c_nonpanel_rgb,c_overlay_rgb,c_text_rgb;
 wire [23:0] c_base=c_panel_window?(c_panel_overlay?c_overlay_rgb:c_panel_rgb):c_nonpanel_rgb;
 wire [23:0] c_final=c_foreground?c_text_rgb:c_base;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   c_valid<=0;c_de<=0;c_hs<=0;c_vs<=0;c_x<=0;c_y<=0;
   c_panel_window<=0;c_panel_overlay<=0;c_foreground<=0;
   c_panel_rgb<=0;c_nonpanel_rgb<=0;c_overlay_rgb<=0;c_text_rgb<=0;
  end else begin
   c_valid<=b_valid;c_de<=b_de;c_hs<=b_hs;c_vs<=b_vs;c_x<=b_x;c_y<=b_y;
   c_panel_window<=b_panel_window;c_panel_overlay<=dot_halo_overlay||dot_disk_overlay;c_foreground<=final_foreground;
   c_panel_rgb<=panel_pixel_rgb;c_nonpanel_rgb<=nonpanel_theme_rgb;
   c_overlay_rgb<=dot_halo_overlay?(b_theme?24'ha76017:24'hffbc66):dot_disk_rgb;
   c_text_rgb<=b_text_rgb;
  end
 end


 // Retain the compatibility/debug net, independent of the selected output cone.

 assign final_base_rgb=dot_halo_overlay?(b_theme?24'ha76017:24'hffbc66):dot_disk_overlay?dot_disk_rgb:b_panel_window?panel_pixel_rgb:b_rgb;





 always @(posedge clk or negedge rst_n)begin



  if(!rst_n)begin



   a_theme<=0;b_theme<=0;a_theme_media<=0;b_theme_media<=0;

   a_theme_brightness<=0;b_theme_brightness<=0;



   a_panel_distance<=0;b_panel_distance<=0;b_cap_upper<=0;b_cap_lower<=0;a_panel_blue<=0;b_panel_blue<=0;b_panel_cap<=0;b_panel_window<=0;b_panel_column<=0;

   a_dot_in_bounds<=0;a_dot_blink<=0;b_dot_valid<=0;b_dot_blink<=0;b_dot_target<=0;b_dot_past<=0;

   a_media_effect<=0;a_fft_window<=0;a_fft_bars<=0;a_service_ui<=0;a_service_menu<=0;a_text_rgb<=24'hffffff;b_text_rgb<=24'hffffff;



   a_numeric<=0;a_digit<=0;a_direct<=0;a_text<=0;a_valid<=0;a_de<=0;a_hs<=0;a_vs<=0;a_glyph<=96;a_gx<=0;a_gy<=0;a_base_events<=0;a_x<=0;a_y<=0;



   b_text<=0;b_valid<=0;b_de<=0;b_hs<=0;b_vs<=0;b_rgb<=0;b_x<=0;b_y<=0;



   out_valid<=0;out_de<=0;out_hs<=0;out_vs<=0;out_x<=0;out_y<=0;out_rgb<=0;



  end else begin



   a_theme<=light_theme&&scene<2;b_theme<=a_theme;

   a_theme_media<=media_effect&&!(fft_window&&!menu_covers_fft);b_theme_media<=a_theme_media;

   a_theme_brightness<=brightness;b_theme_brightness<=a_theme_brightness;



   a_dot_in_bounds<=service_ui&&in_de&&in_x<2048&&in_y<1024;

   a_dot_blink<=service_blink;

   b_dot_valid<=a_dot_in_bounds&&a_dot_x[5]&&a_dot_y[5];

   b_dot_blink<=a_dot_blink;b_dot_target<=a_dot_x[6];b_dot_past<=a_dot_x[7];

   a_media_effect<=media_effect;a_service_ui<=service_ui;a_service_menu<=st_menu;a_text_rgb<=light_theme&&scene<2?light_palette(text_rgb,1'b1,in_x,in_y):text_rgb;b_text_rgb<=a_theme?{theme_dim(a_text_rgb[23:16],a_theme_brightness),theme_dim(a_text_rgb[15:8],a_theme_brightness),theme_dim(a_text_rgb[7:0],a_theme_brightness)}:a_text_rgb;



   a_fft_window<=fft_window&&!menu_covers_fft;

   a_panel_distance<=panel_distance[8:0];b_panel_distance<=a_panel_distance;
    b_cap_upper<=(a_panel_distance>=9'd3)?(a_panel_distance-9'd3):9'd0;
    b_cap_lower<=(a_panel_distance>=9'd6)?(a_panel_distance-9'd6):9'd0;

   a_panel_blue<=light_theme&&scene<2?panel_dim(panel_blue(panel_distance[6:3]),brightness):panel_blue(panel_distance[6:3]);

   b_panel_blue<=a_panel_blue;

   b_panel_cap<=a_theme?panel_dim(24'hefbd23,a_theme_brightness):24'hffdc57;

   b_panel_window<=a_fft_window;b_panel_column<=fft_x_q[5];



   a_numeric<=numeric_pixel;a_digit<=numeric_digit;a_valid<=in_valid;a_direct<=direct;a_glyph<=direct_glyph;a_text<=service_ui?text_enable:parallel_text_enable;a_gx<=service_ui?gx:fast_gx;a_gy<=gy;



   a_base_events<=base_events;a_x<=in_x;a_y<=in_y;a_de<=in_de;a_hs<=in_hs;a_vs<=in_vs;



   b_valid<=a_valid;b_text<=a_text;



   b_rgb<=a_fft_window?

    (a_theme?panel_dim(a_service_ui?24'hfcfcfa:24'hedf2f5,a_theme_brightness):(a_service_ui?24'h142a3c:24'h0b2538)):

    a_media_effect?{finish_color(a_product_r,a_effect_brightness),finish_color(a_product_g,a_effect_brightness),finish_color(a_product_b,a_effect_brightness)}:base_code_rgb(base_event_code(a_base_events),a_theme,a_x,a_y);

   b_x<=a_x;b_y<=a_y;b_de<=a_de;b_hs<=a_hs;b_vs<=a_vs;



   out_valid<=c_valid;out_rgb<=!c_de?0:c_final;



   out_x<=c_x;out_y<=c_y;out_de<=c_de;out_hs<=c_hs;out_vs<=c_vs;



  end



 end



endmodule



