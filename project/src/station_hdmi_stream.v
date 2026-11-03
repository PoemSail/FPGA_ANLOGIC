`timescale 1ns/1ps
// Adapted from reviewed r20f hdmi_av_stream; helpers and pipelined TMDS encoder
// are reused unmodified. hdl-util HDMI helpers: Sameer Puri, MIT, see
// third_party/hdl_util_hdmi/LICENSE-MIT. One 74.25MHz pixel clock, VIC4 720p60.
// Raster continues during media pause. After startup pixel_valid must be 1
// every pixel clock for the physical serializer; no pausing the HDMI raster.
module station_hdmi_stream(
 input wire clk,rst_n,pixel_valid,input wire [11:0] x,y,
 input wire [23:0] rgb,input wire de,hs,vs,
 input wire audio_valid,output wire audio_ready,input wire [15:0] audio_left,audio_right,
 output reg symbol_valid,output wire [29:0] symbols,output reg audio_overflow,
 output reg [31:0] audio_packets,acr_packets,info_packets
);
 wire island=x>=1294&&x<1390;
 wire island_guard=(x>=1292&&x<1294)||(x>=1390&&x<1392);
 wire island_preamble=x>=1284&&x<1292;
 wire next_video=y<719||y==749;
 wire video_guard=next_video&&x>=1648;
 wire video_preamble=next_video&&x>=1640&&x<1648;
 wire select_packet=pixel_valid&&(x==1293||x==1325||x==1357);
 wire [2:0] mode=!rst_n?0:de?1:video_guard?2:island_guard?4:island?3:0;
 wire [5:0] control_data={{1'b0,island_preamble},{1'b0,video_preamble||island_preamble},{vs,hs}};
 reg [23:0] header;reg [223:0] sub;wire [8:0] packet_data;wire [4:0] packet_counter;
 wire [11:0] island_data={packet_data[8:1],1'b1,packet_data[0],vs,hs};
 wire encode_ce=pixel_valid||!rst_n;reg valid_delayed;
 hu_packet_assembler assembler(.clk_pixel(clk),.pixel_ce(encode_ce),.reset(!rst_n),.data_island_period(island),
  .header(header),.sub(sub),.packet_data(packet_data),.counter(packet_counter));
 genvar channel;
 generate for(channel=0;channel<3;channel=channel+1)begin:channels
  hu_tmds_channel_pipelined #(.CN(channel)) encoder(.clk_pixel(clk),.pixel_ce(encode_ce),
   .video_data(rgb[channel*8+:8]),.data_island_data(island_data[channel*4+:4]),
   .control_data(control_data[channel*2+:2]),.mode(mode),.tmds(symbols[channel*10+:10]));
 end endgenerate
 reg [31:0] fifo[0:15];reg [3:0] wp,rp;reg [4:0] count;
 reg [7:0] audio_frame;reg [5:0] acr_samples;reg acr_due,avi_sent,spd_sent,audio_info_sent;
 wire take_audio=select_packet&&!acr_due&&count>=4;
 assign audio_ready=rst_n&&(count<16||take_audio);
 wire put_audio=audio_valid&&audio_ready;
 wire [191:0] packet_samples;genvar sample;
 generate for(sample=0;sample<4;sample=sample+1)begin:samples_in_packet
  wire [3:0] ptr=rp+sample;
  assign packet_samples[sample*48+:48]={fifo[ptr][31:16],8'd0,fifo[ptr][15:0],8'd0};
 end endgenerate
 wire [23:0] sample_header,avi_header,spd_header,info_header;
 wire [223:0] sample_sub,avi_sub,spd_sub,info_sub;
 hu_audio_sample_packet #(.SAMPLING_FREQUENCY(4'b0010),.WORD_LENGTH(4'b0010)) samples(
  .frame_counter(audio_frame),.valid_bit(8'd0),.user_data_bit(8'd0),.audio_sample_word(packet_samples),
  .audio_sample_word_present(4'hf),.header(sample_header),.sub(sample_sub));
 hu_audio_info_frame info(.header(info_header),.sub(info_sub));
 hu_auxiliary_video_information_info_frame #(.VIDEO_ID_CODE(4),.IT_CONTENT(1'b1),
  .RGB_QUANTIZATION_RANGE(2'b10),.PICTURE_ASPECT_RATIO(2'b10)) avi(.header(avi_header),.sub(avi_sub));
 hu_source_product_description_info_frame #(.VENDOR_NAME({"EG4TEAM",8'd0}),
  .PRODUCT_DESCRIPTION({"SMART DISPLAY",24'd0}),.SOURCE_DEVICE_INFORMATION(8'h0d)) spd(.header(spd_header),.sub(spd_sub));
 // fs=fpixel*N/(128*CTS): 74.25MHz, N6144, CTS74250 -> 48kHz.
 localparam [19:0] N=6144,CTS=74250;
 localparam [55:0] ACR_SUB={N[7:0],N[15:8],4'd0,N[19:16],CTS[7:0],CTS[15:8],4'd0,CTS[19:16],8'd0};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   symbol_valid<=0;valid_delayed<=0;header<=0;sub<=0;wp<=0;rp<=0;count<=0;
   audio_frame<=0;acr_samples<=0;acr_due<=1;avi_sent<=0;spd_sent<=0;audio_info_sent<=0;audio_overflow<=0;
   audio_packets<=0;acr_packets<=0;info_packets<=0;
  end else begin
   valid_delayed<=pixel_valid;symbol_valid<=valid_delayed;
   if(put_audio)begin fifo[wp]<={audio_right,audio_left};wp<=wp+1'b1;end
   if(audio_valid&&!audio_ready)audio_overflow<=1;
   case({put_audio,take_audio})2'b10:count<=count+1'b1;2'b01:count<=count-4;2'b11:count<=count-3;default:;endcase
   if(pixel_valid&&x==0&&y==720)begin avi_sent<=0;spd_sent<=0;audio_info_sent<=0;end
   if(select_packet)begin
    if(acr_due)begin header<=24'h000001;sub<={4{ACR_SUB}};acr_due<=0;acr_packets<=acr_packets+1'b1;end
    else if(take_audio)begin
     header<=sample_header;sub<=sample_sub;rp<=rp+4;
     audio_frame<=audio_frame==188?0:audio_frame+4;audio_packets<=audio_packets+1'b1;
    end else if(!audio_info_sent)begin header<=info_header;sub<=info_sub;audio_info_sent<=1;info_packets<=info_packets+1'b1;end
    else if(!avi_sent)begin header<=avi_header;sub<=avi_sub;avi_sent<=1;info_packets<=info_packets+1'b1;end
    else if(!spd_sent)begin header<=spd_header;sub<=spd_sub;spd_sent<=1;info_packets<=info_packets+1'b1;end
    else begin header<=0;sub<=0;end
   end
   if(put_audio)begin
    if(acr_samples==47)begin acr_samples<=0;acr_due<=1;end else acr_samples<=acr_samples+1'b1;
   end
  end
 end
endmodule
