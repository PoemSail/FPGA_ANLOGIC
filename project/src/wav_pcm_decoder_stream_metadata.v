// Streaming semantic flags; RIFF/fmt decisions keep their original cycles.
// Explicit byte writes; original module name, choose one source.
`timescale 1ns/1ps
// RIFF/WAVE PCM16, mono/stereo, 48kHz. Walks unknown chunks and odd padding.
// Byte stream and PCM stream are independently backpressured. Never treats MP3 as PCM.
module wav_pcm_decoder(
 input wire clk,rst_n,start_valid,output wire start_ready,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output reg pcm_valid,input wire pcm_ready,output reg [15:0] pcm_left,pcm_right,
 output wire done_valid,input wire done_ready,output reg [3:0] error_code
);
 localparam IDLE=0,RIFF=1,CHUNK=2,CHECK=3,FMT=4,SKIP=5,DATA=6,PAD=7,DRAIN=8,RESULT=9;
 reg [3:0] state;reg [31:0] size,pos,riff_size,length,remaining;
 reg [15:0] channels;reg riff_bad,fmt_bad,chunk_fmt,chunk_data;
 reg [4:0] index;reg [1:0] sample_byte;reg [7:0] low;reg [15:0] left_work;
 reg fmt_ok,data_seen,closed,odd;
 wire take=byte_valid&&byte_ready;
 assign start_ready=rst_n&&state==IDLE;
 assign byte_ready=rst_n&&!closed&&(state==RIFF||(state==CHUNK&&pos<size)||state==FMT||(state==SKIP&&remaining!=0)||state==PAD||state==DRAIN||(state==DATA&&!pcm_valid));
 assign source_done_ready=rst_n&&!closed&&state!=IDLE&&state!=RESULT;
 assign done_valid=rst_n&&state==RESULT;
 task fail;input [3:0] code;begin if(error_code==0)error_code<=code;pcm_valid<=0;state<=DRAIN;end endtask
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;size<=0;pos<=0;riff_size<=0;length<=0;remaining<=0;riff_bad<=0;fmt_bad<=0;chunk_fmt<=0;chunk_data<=0;
   channels<=0;index<=0;sample_byte<=0;low<=0;left_work<=0;
   fmt_ok<=0;data_seen<=0;closed<=0;odd<=0;pcm_valid<=0;pcm_left<=0;pcm_right<=0;error_code<=0;end
  else begin
   if(pcm_valid&&pcm_ready)pcm_valid<=0;
   if(take)pos<=pos+1'b1;
   case(state)
    IDLE:if(start_valid)begin size<=file_size;pos<=0;index<=0;fmt_ok<=0;data_seen<=0;closed<=0;error_code<=0;pcm_valid<=0;riff_bad<=0;fmt_bad<=0;chunk_fmt<=0;chunk_data<=0;state<=RIFF;end
    RIFF:if(take)begin
     case(index)
      0:if(byte_data!=8'h52)riff_bad<=1;
      1:if(byte_data!=8'h49)riff_bad<=1;
      2:if(byte_data!=8'h46)riff_bad<=1;
      3:if(byte_data!=8'h46)riff_bad<=1;
      4:riff_size[0+:8]<=byte_data;
      5:riff_size[8+:8]<=byte_data;
      6:riff_size[16+:8]<=byte_data;
      7:riff_size[24+:8]<=byte_data;
      8:if(byte_data!=8'h57)riff_bad<=1;
      9:if(byte_data!=8'h41)riff_bad<=1;
      10:if(byte_data!=8'h56)riff_bad<=1;
      11:if(byte_data!=8'h45)riff_bad<=1;
      default:;
     endcase
     if(index==11)begin state<=CHECK;index<=0;chunk_fmt<=0;chunk_data<=0;length<=0;end else index<=index+1'b1;
    end
    CHECK:begin
     if(pos==12)begin if(riff_bad||{1'b0,riff_size}+8!=size)fail(2);else state<=CHUNK;end
     else if({1'b0,pos}+length+{32'b0,length[0]}>size)fail(3);
     else begin remaining<=length;odd<=length[0];index<=0;
      if(chunk_fmt)begin if(length<16||fmt_ok)fail(4);else state<=FMT;end
      else if(chunk_data)begin
       if(!fmt_ok||data_seen||length==0||(channels==2 ? (|length[1:0]):length[0]))fail(4);
       else begin data_seen<=1;sample_byte<=0;state<=DATA;end
      end else if(length==0)state<=CHUNK;else state<=SKIP;
     end
    end
    CHUNK:if(pos==size)begin if(!data_seen)fail(4);else state<=DRAIN;end
     else if(take)begin
      case(index)
       0:begin chunk_fmt<=byte_data==8'h66;chunk_data<=byte_data==8'h64;end
       1:begin chunk_fmt<=chunk_fmt && byte_data==8'h6d;chunk_data<=chunk_data && byte_data==8'h61;end
       2:begin chunk_fmt<=chunk_fmt && byte_data==8'h74;chunk_data<=chunk_data && byte_data==8'h74;end
       3:begin chunk_fmt<=chunk_fmt && byte_data==8'h20;chunk_data<=chunk_data && byte_data==8'h61;end
       4:length[0+:8]<=byte_data;
       5:length[8+:8]<=byte_data;
       6:length[16+:8]<=byte_data;
       7:length[24+:8]<=byte_data;
       default:;
      endcase
      if(index==7)begin state<=CHECK;index<=0;end else index<=index+1'b1;
     end
    FMT:if(take)begin
     case(index)
      0:fmt_bad<=byte_data!=8'd1;1:if(byte_data!=0)fmt_bad<=1;
      2:channels[7:0]<=byte_data;3:channels[15:8]<=byte_data;
      4:if(byte_data!=8'h80)fmt_bad<=1;
      5:if(byte_data!=8'hbb)fmt_bad<=1;
      6:if(byte_data!=8'h00)fmt_bad<=1;
      7:if(byte_data!=8'h00)fmt_bad<=1;
      8:if(byte_data!=8'd0)fmt_bad<=1;
      9:if(byte_data!=(channels==2?8'hee:8'h77))fmt_bad<=1;
      10:if(byte_data!=(channels==2?8'd2:8'd1))fmt_bad<=1;
      11:if(byte_data!=8'd0)fmt_bad<=1;
      12:if(byte_data!=(channels==2?8'd4:8'd2))fmt_bad<=1;13:if(byte_data!=0)fmt_bad<=1;
      14:if(byte_data!=8'd16)fmt_bad<=1;15:if(byte_data!=0)fmt_bad<=1;
     endcase
     remaining<=remaining-1'b1;
     if(index==15)begin state<=10;index<=16;end else index<=index+1'b1;
    end
    10:begin
      if(fmt_bad||(channels!=1&&channels!=2))fail(4);
      else begin fmt_ok<=1;state<=remaining==0 ? (odd ? PAD:CHUNK):SKIP;index<=0;end
    end
    SKIP:begin
     if(remaining==0)begin state<=odd ? PAD:CHUNK;index<=0;end
     else if(take)begin remaining<=remaining-1'b1;if(remaining==1)begin state<=odd ? PAD:CHUNK;index<=0;end end
    end
    DATA:if(take)begin
     remaining<=remaining-1'b1;
     case(sample_byte)
      0:begin low<=byte_data;sample_byte<=1;end
      1:if(channels==1)begin pcm_left<={byte_data,low};pcm_right<={byte_data,low};pcm_valid<=1;sample_byte<=0;end
        else begin left_work<={byte_data,low};sample_byte<=2;end
      2:begin low<=byte_data;sample_byte<=3;end
      3:begin pcm_left<=left_work;pcm_right<={byte_data,low};pcm_valid<=1;sample_byte<=0;end
     endcase
     if(remaining==1)begin state<=odd ? PAD:CHUNK;index<=0;end
    end
    PAD:if(take)begin state<=CHUNK;index<=0;end
    DRAIN:if(closed&&!pcm_valid)begin if(!data_seen&&error_code==0)error_code<=4;state<=RESULT;end
    RESULT:if(done_ready)state<=IDLE;
   endcase
   if(closed&&state!=IDLE&&state!=RESULT&&state!=DRAIN)begin
    if(pos!=size||state!=CHUNK||index!=0)begin if(error_code==0)error_code<=5;pcm_valid<=0;end state<=DRAIN;
   end
   if(source_done_valid&&source_done_ready)begin closed<=1;if(source_done_error)fail(1);end
   if(take&&byte_last!=(pos==size-1))fail(5);
  end
 end
endmodule
