`timescale 1ns/1ps
// Ordered480x270 RGB565 pixels -> stride256-word surface.
// Two pixels/word, low half first. Only accepted physical write completions
// release credits. Publish after source closure AND all physical writes drain.
// Successful descriptor transfers ownership; explicit release permits reuse.
// Cancel/errors discard only an unaccepted pair and drain accepted writes.
module station_photo_surface #(
 parameter [20:0] SURFACE_BASE=21'h40000,
 parameter integer MAX_PENDING=16
)(
 input wire clk,rst_n,mem_initialized,start_valid,output wire start_ready,input wire cancel,
 input wire pixel_valid,output wire pixel_ready,input wire [17:0] pixel_address,input wire [15:0] pixel_rgb565,
 input wire source_done_valid,output wire source_done_ready,input wire [3:0] source_error,
 output wire cancel_source,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,output wire [7:0] error_code,
 output wire [20:0] descriptor_base,input wire release_surface,output wire memory_quiet,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam IDLE=0,ACTIVE=1,REPORT=2,HELD=3,CW=bits_for(MAX_PENDING+1);
 reg [1:0] state;reg [CW-1:0] pending;reg [17:0] pixels;
 reg [16:0] words;reg [8:0] column,row;
 reg [15:0] low_pixel;reg word_valid,closed;reg [31:0] word_data;reg [20:0] word_address;
 reg [3:0] write_error,source_code;
 wire abort_now=cancel||write_error!=0||source_code!=0;
 wire [21:0] address_sum={1'b0,SURFACE_BASE}+{5'd0,row,8'd0}+{13'd0,column[8:1]};
 assign start_ready=rst_n&&mem_initialized&&state==IDLE&&!cancel;
 assign pixel_ready=rst_n&&state==ACTIVE&&!closed&&!abort_now&&!word_valid&&pixels<129600;
 assign source_done_ready=rst_n&&state==ACTIVE&&!closed;
 assign cancel_source=rst_n&&state==ACTIVE&&abort_now;
 assign mem_wr_valid=rst_n&&state==ACTIVE&&!abort_now&&word_valid&&pending<MAX_PENDING;
 assign mem_wr_address=word_address;assign mem_wr_data=word_data;
 assign mem_wr_rsp_ready=rst_n&&state==ACTIVE;
 assign descriptor_valid=rst_n&&state==REPORT;
 assign descriptor_error=write_error!=0||source_code!=0||cancel;
 assign error_code={write_error,(cancel&&source_code==0?4'd2:source_code)};
 assign descriptor_base=SURFACE_BASE;
 assign memory_quiet=rst_n&&pending==0&&!word_valid&&!mem_wr_valid&&!mem_wr_rsp_valid;
 wire put=mem_wr_valid&&mem_wr_ready,ack=mem_wr_rsp_valid&&mem_wr_rsp_ready;
 wire pixel_put=pixel_valid&&pixel_ready;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;pending<=0;pixels<=0;words<=0;column<=0;row<=0;low_pixel<=0;
   word_valid<=0;closed<=0;word_data<=0;word_address<=0;write_error<=0;source_code<=0;
  end else begin
   case({put,(ack&&pending!=0)})2'b10:pending<=pending+1'b1;2'b01:if(pending!=0)pending<=pending-1'b1;default:;endcase
   if(put)begin word_valid<=0;words<=words+1'b1;end
   if(ack&&write_error==0)begin
    if(pending==0)write_error<=1;
    else if(mem_wr_rsp_error)write_error<=2;
   end
   if(pixel_put)begin
    if(pixel_address!=pixels)write_error<=4;
    else if(!pixels[0])low_pixel<=pixel_rgb565;
    else if(address_sum[21])write_error<=5;
    else begin word_valid<=1;word_data<={pixel_rgb565,low_pixel};word_address<=address_sum[20:0];end
    pixels<=pixels+1'b1;
    if(column==479)begin column<=0;row<=row+1'b1;end else column<=column+1'b1;
   end
   if(state==ACTIVE&&pixel_valid&&!closed&&pixels==129600&&write_error==0)write_error<=4;
   if(source_done_valid&&source_done_ready)begin closed<=1;if(source_code==0)source_code<=source_error;end
   if(state==ACTIVE&&abort_now)word_valid<=0;
   if(state==ACTIVE&&cancel&&source_code==0)source_code<=2;
   case(state)
    IDLE:if(start_valid&&start_ready)begin
     state<=ACTIVE;pending<=0;pixels<=0;words<=0;column<=0;row<=0;word_valid<=0;closed<=0;
     write_error<=MAX_PENDING<1||MAX_PENDING>64?6:0;source_code<=0;
    end
    ACTIVE:if(closed&&pending==0&&!ack&&(!word_valid||abort_now))begin
     if(write_error==0&&source_code==0&&!cancel&&(pixels!=129600||words!=64800))write_error<=3;
     state<=REPORT;
    end
    REPORT:begin
     if(cancel&&source_code==0)source_code<=2;
     if(descriptor_ready)state<=descriptor_error?IDLE:HELD;
    end
    HELD:if(release_surface)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
