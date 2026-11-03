// Fixed semantic checks are sticky until the unchanged validation cycle.
// Explicit byte writes; original module name, choose one source.
`timescale 1ns/1ps
// Bounded BMP24 BI_RGB -> row-major RGB888 scratch pixel stream.
// Adapted from reviewed bmp24_decoder; header checks/closure/row order retained.
// Dynamic1..1024 x1..768, no line RAM.20-bit address covers786432 pixels.
// Every pixel is an UNCOMMITTED candidate until done succeeds and memory drains.
module station_bmp_source #(
 parameter integer MAX_FILE_BYTES=4194304,MAX_WIDTH=1024,MAX_HEIGHT=768
)(
 input wire clk,rst_n,start_valid,output wire start_ready,input wire [31:0] file_size,
 input wire cancel,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire meta_valid,input wire meta_ready,output reg [15:0] width,height,output wire [19:0] total_pixels,
 output wire pixel_valid,input wire pixel_ready,output reg [19:0] pixel_address,output reg [23:0] pixel_rgb,
 output wire done_valid,input wire done_ready,output wire done_error,output reg [3:0] error_code
);
 localparam IDLE=0,HEADER=1,VALIDATE=2,SIZE=3,CHECK=4,META=5,GAP=6,BGR=7,PIXEL=8,PADDING=9,DRAIN=10,RESULT=11;
 reg [3:0] state;
 reg [31:0] size_latched,position,bf_size,offset,width_field,height_field,image_size,raster_bytes;
 reg header_bad;
 reg closed,complete_pixels,bottom_up;reg [1:0] channel,pad_size,pad_left;
 reg [7:0] blue,green;reg [19:0] row_base;reg [10:0] x;reg [9:0] row;
 wire [31:0] abs_height=height_field[31]?(32'd0-height_field):height_field;
 wire [20:0] product=width[10:0]*height[9:0];
 wire [1:0] padding=(4-(width[10:0]*3)%4)%4;
 wire [21:0] padding_total=padding==0?0:padding==1?{12'd0,height[9:0]}:
  padding==2?{11'd0,height[9:0],1'b0}:({12'd0,height[9:0]}+{11'd0,height[9:0],1'b0});
 assign total_pixels=product[19:0];
 wire transfer=byte_valid&&byte_ready;
 assign start_ready=rst_n&&state==IDLE;
 assign byte_ready=rst_n&&!closed&&(state==DRAIN||(!cancel&&(state==HEADER||state==GAP||state==BGR||state==PADDING)));
 assign source_done_ready=rst_n&&!closed&&state!=IDLE&&state!=RESULT;
 assign meta_valid=rst_n&&state==META&&!cancel&&error_code==0;
 assign pixel_valid=rst_n&&state==PIXEL&&!cancel&&error_code==0;
 assign done_valid=rst_n&&state==RESULT;assign done_error=error_code!=0;
 task fail;input [3:0] code;begin if(error_code==0)error_code<=code;state<=DRAIN;end endtask
 task next_row;begin
  if(row==height-1'b1)begin complete_pixels<=1;state<=DRAIN;end
  else begin row<=row+1'b1;row_base<=bottom_up?row_base-width:row_base+width;state<=BGR;end
 end endtask
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;size_latched<=0;position<=0;bf_size<=0;offset<=0;width_field<=0;height_field<=0;
   image_size<=0;raster_bytes<=0;header_bad<=0;width<=0;height<=0;
   closed<=0;complete_pixels<=0;bottom_up<=0;channel<=0;pad_size<=0;pad_left<=0;
   blue<=0;green<=0;row_base<=0;x<=0;row<=0;pixel_address<=0;pixel_rgb<=0;error_code<=0;
  end else begin
   if(transfer)position<=position+1'b1;
   case(state)
    IDLE:if(start_valid)begin
     size_latched<=file_size;position<=0;closed<=0;complete_pixels<=0;error_code<=0;header_bad<=0;x<=0;row<=0;channel<=0;width<=0;height<=0;
     if(file_size<54||file_size>MAX_FILE_BYTES)begin error_code<=2;state<=DRAIN;end else state<=HEADER;
    end
    HEADER:if(transfer)begin
     case(position)
      0:if(byte_data!=8'h42)header_bad<=1;1:if(byte_data!=8'h4d)header_bad<=1;
      2:bf_size[0+:8]<=byte_data;
      3:bf_size[8+:8]<=byte_data;
      4:bf_size[16+:8]<=byte_data;
      5:bf_size[24+:8]<=byte_data;
      6:if(byte_data!=8'h00)header_bad<=1;
      7:if(byte_data!=8'h00)header_bad<=1;
      8:if(byte_data!=8'h00)header_bad<=1;
      9:if(byte_data!=8'h00)header_bad<=1;
      10:offset[0+:8]<=byte_data;
      11:offset[8+:8]<=byte_data;
      12:offset[16+:8]<=byte_data;
      13:offset[24+:8]<=byte_data;
      14:if(byte_data!=8'h28)header_bad<=1;
      15:if(byte_data!=8'h00)header_bad<=1;
      16:if(byte_data!=8'h00)header_bad<=1;
      17:if(byte_data!=8'h00)header_bad<=1;
      18:width_field[0+:8]<=byte_data;
      19:width_field[8+:8]<=byte_data;
      20:width_field[16+:8]<=byte_data;
      21:width_field[24+:8]<=byte_data;
      22:height_field[0+:8]<=byte_data;
      23:height_field[8+:8]<=byte_data;
      24:height_field[16+:8]<=byte_data;
      25:height_field[24+:8]<=byte_data;
      26:if(byte_data!=8'd1)header_bad<=1;27:if(byte_data!=0)header_bad<=1;
      28:if(byte_data!=8'd24)header_bad<=1;29:if(byte_data!=0)header_bad<=1;
      30:if(byte_data!=8'h00)header_bad<=1;
      31:if(byte_data!=8'h00)header_bad<=1;
      32:if(byte_data!=8'h00)header_bad<=1;
      33:if(byte_data!=8'h00)header_bad<=1;
      34:image_size[0+:8]<=byte_data;
      35:image_size[8+:8]<=byte_data;
      36:image_size[16+:8]<=byte_data;
      37:image_size[24+:8]<=byte_data;
      default:;
     endcase
     if(position==53)state<=VALIDATE;
    end
    VALIDATE:begin
     if(header_bad)fail(3);
     else if(width_field==0||width_field>MAX_WIDTH||width_field>1024||abs_height==0||abs_height>MAX_HEIGHT||abs_height>768)fail(4);
     else begin width<=width_field[15:0];height<=abs_height[15:0];bottom_up<=!height_field[31];state<=SIZE;end
    end
    SIZE:begin raster_bytes<=product*3+padding_total;pad_size<=padding;state<=CHECK;end
    CHECK:begin
     if(bf_size!=size_latched||offset<54||{1'b0,offset}+{1'b0,raster_bytes}>{1'b0,size_latched}||
       (image_size!=0&&image_size!=raster_bytes))fail(5);
     else begin row_base<=bottom_up?total_pixels-width:0;state<=META;end
    end
    META:if(meta_ready)state<=position==offset?BGR:GAP;
    GAP:if(transfer&&position+1==offset)state<=BGR;
    BGR:if(transfer)case(channel)
     0:begin blue<=byte_data;channel<=1;end
     1:begin green<=byte_data;channel<=2;end
     2:begin pixel_rgb<={byte_data,green,blue};pixel_address<=row_base+x;channel<=0;state<=PIXEL;end
     default:fail(7);
    endcase
    PIXEL:if(pixel_ready)begin
     if(x==width-1'b1)begin x<=0;if(pad_size!=0)begin pad_left<=pad_size;state<=PADDING;end else next_row;end
     else begin x<=x+1'b1;state<=BGR;end
    end
    PADDING:if(transfer)begin if(pad_left==1)next_row;else pad_left<=pad_left-1'b1;end
    DRAIN:if(closed)begin
     if(error_code==0&&(!complete_pixels||position!=size_latched))error_code<=7;
     state<=RESULT;
    end
    RESULT:if(done_ready)state<=IDLE;
    default:fail(7);
   endcase
   // Exact last-byte marker and early closure are distinct from stored row order.
   if(closed&&state!=IDLE&&state!=RESULT&&state!=DRAIN&&state!=PIXEL)fail(7);
   if(source_done_valid&&source_done_ready)begin closed<=1;if(source_done_error)fail(1);end
   if(transfer&&byte_last!=(position==size_latched-1))fail(6);
   if(cancel&&state!=IDLE&&state!=RESULT&&state!=DRAIN)fail(8);
  end
 end
endmodule
