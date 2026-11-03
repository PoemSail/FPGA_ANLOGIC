// Independent candidate; parent SHA256 9fe5e3f7f649f2e4dd7fbb6ba5487b862c511066560ef92effdefdd424846c16
`timescale 1ns/1ps
// Two RGB565 line banks, bundled-data toggle mailboxes and 720p NN scaler.
// Common asynchronous reset assertion is REQUIRED, including the attached DMA.
// Each domain synchronously releases reset; one-sided reset is unsupported.
// No frame buffer: 512 packed words (two 256-word banks), one sync RAM read.
// Physical CDC/max-delay/reset constraints remain an implementation requirement.
module station_video_pixel_bridge #(parameter integer MEDIA_VIEWPORT=0)(
 input wire bus_clk,pixel_clk,arst_n,
 input wire display_valid,input wire [63:0] display_pts,
 input wire [15:0] display_width,display_height,
 output reg frame_boundary,output wire pixel_swap_safe,
 output wire row_valid,input wire row_ready,output wire [8:0] row,output wire [63:0] row_pts,
 input wire word_valid,input wire [7:0] word_index,input wire [31:0] word_data,
 input wire line_done,line_rejected,input wire [8:0] line_row,input wire [63:0] line_pts,
 input wire line_fault,output reg bus_fault,
 input wire [11:0] x,y,input wire de,hs,vs,vblank_start,
 output reg [23:0] out_rgb,output reg [11:0] out_x,out_y,
 output reg out_de,out_hs,out_vs,output wire pixel_fault,
 output reg [31:0] underflow_lines
);
 wire brst,prst;
 reset_sync br(.clk(bus_clk),.arst_n(arst_n),.rst_n(brst));
 reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 reg [31:0] ram[0:511];reg [31:0] pixel_word;
 // Pixel->bus: request toggles and held row/bank/PTS. Payload stays held
 // until matching acknowledgement has crossed back through two flops.
 reg p_line_request,p_window_request,p_request_bank;
 reg [8:0] p_request_row;reg [63:0] p_request_pts;
 reg b_line_ack,b_window_ack,b_line_ok;
 reg line_meta,line_sync,window_meta,window_sync;
 reg ack_meta,ack_sync,desc_meta,desc_sync,fault_meta,fault_sync;
 reg b_desc_valid;reg [63:0] b_desc_pts;reg [15:0] b_desc_width,b_desc_height;
 localparam B_IDLE=0,B_OFFER=1,B_FILL=2;
 reg [1:0] b_state,b_window_state;reg b_bank;
 reg [8:0] b_row,b_words;reg [63:0] b_pts;reg [8:0] b_expected;
 assign row_valid=brst&&b_state==B_OFFER&&!bus_fault;
 assign row=b_row;assign row_pts=b_pts;
 assign pixel_swap_safe=frame_boundary&&brst&&!bus_fault&&b_state==B_IDLE;
 wire accepted_word=word_valid&&b_state==B_FILL&&!bus_fault&&word_index==b_words&&b_words<b_expected;
 // Intentional dual-clock, simple dual-port RAM. Never reset the array.
 always @(posedge bus_clk)if(accepted_word)ram[{b_bank,word_index}]<=word_data;
 always @(posedge bus_clk or negedge brst)begin
  if(!brst)begin
   line_meta<=0;line_sync<=0;window_meta<=0;window_sync<=0;
   b_line_ack<=0;b_window_ack<=0;b_line_ok<=0;b_desc_valid<=0;
   b_desc_pts<=0;b_desc_width<=0;b_desc_height<=0;
   b_state<=B_IDLE;b_window_state<=0;b_bank<=0;b_row<=0;b_pts<=0;b_words<=0;b_expected<=0;
   frame_boundary<=0;bus_fault<=0;
  end else begin
   line_meta<=p_line_request;line_sync<=line_meta;
   window_meta<=p_window_request;window_sync<=window_meta;
   frame_boundary<=0;
   if(line_fault)bus_fault<=1;
   if(word_valid&&(!accepted_word||b_state!=B_FILL))bus_fault<=1;
   if(line_done&&b_state!=B_FILL)bus_fault<=1;
   // Detection, pulse, one post-publication clock, then held descriptor+ack.
   case(b_window_state)
    0:if(window_sync!=b_window_ack&&b_state==B_IDLE)begin
     // Window notification also clocks control/fault pages. A bad video
     // must not stop UI commits; pixel_swap_safe separately forbids swaps.
     frame_boundary<=1'b1;b_window_state<=1;
    end
    1:b_window_state<=2;
    2:begin
     b_desc_valid<=display_valid&&!bus_fault&&!line_fault;
     b_desc_pts<=display_pts;b_desc_width<=display_width;b_desc_height<=display_height;
     b_window_ack<=window_sync;b_window_state<=0;
    end
    default:begin b_window_state<=0;bus_fault<=1;end
   endcase
   case(b_state)
    B_IDLE:if(line_sync!=b_line_ack&&b_window_state==0&&window_sync==b_window_ack)begin
     b_bank<=p_request_bank;b_row<=p_request_row;b_pts<=p_request_pts;b_words<=0;
     b_expected<=display_width==320?9'd160:9'd240;
     if(bus_fault||line_fault||!display_valid||p_request_pts!=display_pts||p_request_row>=display_height)begin
      b_line_ok<=0;b_line_ack<=line_sync;
     end else b_state<=B_OFFER;
    end
    B_OFFER:if(line_fault||bus_fault)begin b_line_ok<=0;b_line_ack<=line_sync;b_state<=B_IDLE;end
     else if(row_valid&&row_ready)b_state<=B_FILL;
    B_FILL:begin
     if(accepted_word)b_words<=b_words+1'b1;
     if(line_done||line_rejected||line_fault||bus_fault)begin
      b_line_ok<=line_done&&!line_rejected&&!line_fault&&!bus_fault&&b_words==b_expected&&line_row==b_row&&line_pts==b_pts;
      if(line_done&&(b_words!=b_expected||line_row!=b_row||line_pts!=b_pts))bus_fault<=1;
      b_line_ack<=line_sync;b_state<=B_IDLE;
     end
    end
    default:begin bus_fault<=1;b_state<=B_IDLE;end
   endcase
  end
 end
 // Pixel bank ownership is never granted for overwrite while an output line
 // reads that bank. Completed rows are tagged; late rows cannot impersonate one.
 reg p_line_pending,p_window_pending,p_need_window,p_desc_settle;
 // Held bus result is captured only after the two-stage line ack.
 // Keep the request pending through one extra local clock before bank commit.
 // Raw cross-domain data feeds only this D input, never bank-row CE logic.
 reg p_line_result,p_line_settle;
 reg p_view_valid,p_large,p_local_fault;reg [63:0] p_pts;
 reg [8:0] p_height,bank_row0,bank_row1;reg [1:0] bank_valid;
 reg line_ok;reg s1_ok,s1_de,s1_hs,s1_vs,s1_half;
 reg [11:0] s1_x,s1_y;
 wire [13:0] scaled_x={2'b0,x}+({2'b0,x}<<1);
 wire [13:0] scaled_y={2'b0,y}+({2'b0,y}<<1);
 wire [8:0] source_x,source_y;
 wire media_active,media_prefetch,media_first;
 generate if(MEDIA_VIEWPORT!=0)begin:viewport
  station_media_coordinates coordinates(.pixel_clk(pixel_clk),.rst_n(prst),.large_profile(p_large),.x(x),.y(y),
   .active(media_active),.prefetch(media_prefetch),.first_pixel(media_first),.source_x(source_x),.source_y(source_y));
 end else begin:full_screen
  assign source_x=p_large?scaled_x[11:3]:x[10:2];
  assign source_y=p_large?scaled_y[11:3]:y[10:2];
  assign media_active=x<1280&&y<720;assign media_prefetch=y>=720;assign media_first=x==0;
 end endgenerate
 wire current_match=p_view_valid&&!pixel_fault&&
  (source_y[0]?(bank_valid[1]&&bank_row1==source_y):(bank_valid[0]&&bank_row0==source_y));
 wire current_ok=media_first?current_match:line_ok;
 wire [8:0] next_row=source_y+1'b1;
 wire next_match=next_row[0]?(bank_valid[1]&&bank_row1==next_row):(bank_valid[0]&&bank_row0==next_row);
 wire first_row_match=bank_valid[0]&&bank_row0==0;
 wire second_row_match=bank_valid[1]&&bank_row1==1;
 reg want_valid;reg [8:0] want_row;
 assign pixel_fault=p_local_fault||fault_sync;
 always @*begin
  want_valid=0;want_row=0;
  if(p_view_valid&&!pixel_fault&&!p_need_window&&!p_window_pending&&!vblank_start)begin
   if(media_prefetch)begin
    if(!first_row_match)begin want_valid=1;want_row=0;end
    else if(!second_row_match)begin want_valid=1;want_row=1;end
   end else if(media_active&&source_y<p_height)begin
    if(!current_match)begin want_valid=1;want_row=source_y;end
    else if(next_row<p_height&&!next_match)begin want_valid=1;want_row=next_row;end
   end
  end
 end
 always @(posedge pixel_clk)if(de&&media_active)pixel_word<=ram[{source_y[0],source_x[8:1]}];
 wire [15:0] packed_pixel=s1_half?pixel_word[31:16]:pixel_word[15:0];
 wire [23:0] expanded={{packed_pixel[15:11],packed_pixel[15:13]},
                      {packed_pixel[10:5],packed_pixel[10:9]},
                      {packed_pixel[4:0],packed_pixel[4:2]}};
 always @(posedge pixel_clk or negedge prst)begin
  if(!prst)begin
   ack_meta<=0;ack_sync<=0;desc_meta<=0;desc_sync<=0;fault_meta<=0;fault_sync<=0;
   p_line_request<=0;p_window_request<=0;p_request_bank<=0;p_request_row<=0;p_request_pts<=0;
   p_line_pending<=0;p_window_pending<=0;p_need_window<=0;p_desc_settle<=0;
   p_line_result<=0;p_line_settle<=0;
   p_view_valid<=0;p_large<=0;p_local_fault<=0;p_pts<=0;p_height<=0;
   bank_valid<=0;bank_row0<=0;bank_row1<=0;line_ok<=0;underflow_lines<=0;
   s1_ok<=0;s1_de<=0;s1_hs<=0;s1_vs<=0;s1_half<=0;s1_x<=0;s1_y<=0;
   out_rgb<=0;out_x<=0;out_y<=0;out_de<=0;out_hs<=0;out_vs<=0;
  end else begin
   ack_meta<=b_line_ack;ack_sync<=ack_meta;desc_meta<=b_window_ack;desc_sync<=desc_meta;
   fault_meta<=bus_fault;fault_sync<=fault_meta;
   s1_x<=x;s1_y<=y;s1_de<=de;s1_hs<=hs;s1_vs<=vs;s1_half<=source_x[0];s1_ok<=media_active&&current_ok;
   out_x<=s1_x;out_y<=s1_y;out_de<=s1_de;out_hs<=s1_hs;out_vs<=s1_vs;
   out_rgb<=s1_de&&s1_ok&&!pixel_fault?expanded:24'd0;
   if(media_first)begin
    line_ok<=current_match;
    if(media_active&&!current_match&&underflow_lines!=32'hffffffff)underflow_lines<=underflow_lines+1'b1;
   end
   if(p_line_pending&&ack_sync==p_line_request&&!p_line_settle)begin
    p_line_result<=b_line_ok;p_line_settle<=1;
   end
   if(p_line_pending&&p_line_settle)begin
    p_line_pending<=0;p_line_settle<=0;
    if(p_line_result)begin
     if(p_request_bank)begin bank_valid[1]<=1;bank_row1<=p_request_row;end
     else begin bank_valid[0]<=1;bank_row0<=p_request_row;end
    end
   end
   if(vblank_start)begin p_need_window<=1;p_view_valid<=0;end
   if(p_need_window&&!p_line_pending&&!p_window_pending)begin
    p_window_request<=!p_window_request;p_window_pending<=1;p_need_window<=0;
    p_view_valid<=0;bank_valid<=0;
   end
   if(p_window_pending&&desc_sync==p_window_request)p_desc_settle<=1;
   // Wait an extra clock for bundled payload and commit ONLY during blank.
   // A late descriptor leaves the entire active remainder black until blank.
   if(p_window_pending&&p_desc_settle&&y>=720)begin
    p_window_pending<=0;p_desc_settle<=0;
    p_pts<=b_desc_pts;p_height<=b_desc_height[8:0];p_large<=b_desc_width==480;
    p_view_valid<=b_desc_valid&&!pixel_fault;
    if(b_desc_valid&&!((b_desc_width==320&&b_desc_height==180)||(b_desc_width==480&&b_desc_height==270)))p_local_fault<=1;
   end
   if(want_valid&&!p_line_pending)begin
    p_request_row<=want_row;p_request_bank<=want_row[0];p_request_pts<=p_pts;
    p_line_request<=!p_line_request;p_line_pending<=1;
    if(want_row[0])bank_valid[1]<=0;else bank_valid[0]<=0;
   end
  end
 end
endmodule
