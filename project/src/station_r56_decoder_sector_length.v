// Exact sector-domain length; original decoder preserved.
// Shared CRC combinational network, same module name; choose one decoder.
// Stream constant checks, retain public metadata/CRCs. Choose ONE decoder source.
`timescale 1ns/1ps
// BSTR1: validated metadata -> reservation -> packed writes -> CRC -> commit.
// Packed words are LITTLE ENDIAN; video pair0 is low16, PCM left is low16.
// Writes go ONLY to an uncommitted destination. Caller owns source timeout/cancel.
module station_r56_decoder(
 input wire clk,rst_n,start_valid,output wire start_ready,input wire [31:0] file_size,
 input wire cancel,input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output reg file_header_valid,output wire [15:0] width,height,output wire [31:0] frame_count,
 output wire [11:0] audio_samples_per_frame,
 output wire record_valid,input wire record_ready,output reg [31:0] record_index,output wire [63:0] record_pts,
 output reg video_valid,input wire video_ready,output reg [16:0] video_offset,output reg [31:0] video_data,
 output reg audio_valid,input wire audio_ready,output reg [10:0] audio_offset,output reg [31:0] audio_data,
 output wire commit_valid,input wire commit_ready,output reg record_abort,
 output wire done_valid,input wire done_ready,output reg [3:0] error_code
);
 localparam IDLE=0,FILE_HEADER=1,FILE_CHECK=2,LENGTH=3,LENGTH_CHECK=4,
  RECORD_HEADER=5,RECORD_CHECK=6,RESERVE=7,VIDEO=8,AUDIO=9,VERIFY=10,COMMIT=11,
  FINISH=12,DRAIN=13,RESULT=14;
 reg [3:0] state;reg [31:0] size,position;
 // Only useful fields are retained; no 512-byte header frame buffer.
 reg [63:0] file_values;reg [127:0] record_values;
 reg file_bad_s0,file_bad_s1,record_bad;reg is_60fps;
 wire [11:0] cur_audio_samples = is_60fps ? 12'd800 : 12'd2000;
 wire [13:0] cur_audio_bytes = is_60fps ? 14'd3200 : 14'd8000;
 wire [31:0] pts_60fps = (record_index << 9) + (record_index << 8) + (record_index << 5);
 wire [31:0] pts_24fps = (record_index << 11) - ((record_index << 5) + (record_index << 4));
 wire [63:0] expected_record_pts = {32'd0, is_60fps ? pts_60fps : pts_24fps};
 assign audio_samples_per_frame = cur_audio_samples;
 reg [8:0] header_index;reg [31:0] header_crc,stored_crc;
 reg reserved_nonzero,closed,allocated;
 reg [18:0] video_bytes,video_padded,payload_index;
 reg [31:0] video_crc,audio_crc;reg [1:0] lane;reg [31:0] assembly;
 reg [8:0] row;reg [7:0] column;reg [10:0] audio_word;
 reg [41:0] length_sectors,term_sectors;reg [31:0] length_bits;reg [5:0] length_step;
 assign width=file_values[0+:16];assign height=file_values[16+:16];assign frame_count=file_values[32+:32];
 assign record_pts=record_values[0+:64];
 wire s1=width==480&&height==270;
 wire external_error=cancel||(source_done_valid&&source_done_ready&&source_done_error)||
  (closed&&position!=size&&error_code==0);
 assign start_ready=rst_n&&state==IDLE;
 assign byte_ready=rst_n&&!closed&&!cancel&&
  (state==FILE_HEADER||state==RECORD_HEADER||state==DRAIN||
   (state==VIDEO&&(!video_valid||video_ready))||(state==AUDIO&&(!audio_valid||audio_ready)));
 assign source_done_ready=rst_n&&!closed&&state!=IDLE&&state!=RESULT;
 assign record_valid=rst_n&&state==RESERVE&&!external_error&&error_code==0;
 assign commit_valid=rst_n&&state==COMMIT&&!video_valid&&!audio_valid&&!external_error&&error_code==0;
 assign done_valid=rst_n&&state==RESULT;
 wire take=byte_valid&&byte_ready;
 function [31:0] crc32_byte;
  input [31:0] previous;input [7:0] data;reg [31:0] c;integer i;
  begin c=previous^{24'd0,data};for(i=0;i<8;i=i+1)c=c[0]?(c>>1)^32'hedb88320:(c>>1);crc32_byte=c;end
 endfunction
 // Exactly one of the three states can consume a byte on a given clock.
 // Retain all three CRC registers; only the combinational next-byte network
 // is shared. Enables, reset values, CRC checks and public timing stay intact.
 wire [31:0] crc_previous=state==VIDEO?video_crc:state==AUDIO?audio_crc:header_crc;
 wire [31:0] shared_crc=crc32_byte(crc_previous,byte_data);
 task fail;
  input [3:0] reason;
  begin
   if(error_code==0)error_code<=reason;
   state<=DRAIN;record_abort<=allocated;allocated<=0;video_valid<=0;audio_valid<=0;
  end
 endtask
 // Unreset metadata is invalid until the corresponding complete header checks pass.
 always @(posedge clk)begin
  if(take&&state==FILE_HEADER)case(header_index)
   9'd8:file_values[0+:8]<=byte_data;
   9'd9:file_values[8+:8]<=byte_data;
   9'd10:file_values[16+:8]<=byte_data;
   9'd11:file_values[24+:8]<=byte_data;
   9'd32:file_values[32+:8]<=byte_data;
   9'd33:file_values[40+:8]<=byte_data;
   9'd34:file_values[48+:8]<=byte_data;
   9'd35:file_values[56+:8]<=byte_data;
   default:;
  endcase
  if(take&&state==RECORD_HEADER)case(header_index)
   9'd8:record_values[0+:8]<=byte_data;
   9'd9:record_values[8+:8]<=byte_data;
   9'd10:record_values[16+:8]<=byte_data;
   9'd11:record_values[24+:8]<=byte_data;
   9'd12:record_values[32+:8]<=byte_data;
   9'd13:record_values[40+:8]<=byte_data;
   9'd14:record_values[48+:8]<=byte_data;
   9'd15:record_values[56+:8]<=byte_data;
   9'd16:record_values[64+:8]<=byte_data;
   9'd17:record_values[72+:8]<=byte_data;
   9'd18:record_values[80+:8]<=byte_data;
   9'd19:record_values[88+:8]<=byte_data;
   9'd20:record_values[96+:8]<=byte_data;
   9'd21:record_values[104+:8]<=byte_data;
   9'd22:record_values[112+:8]<=byte_data;
   9'd23:record_values[120+:8]<=byte_data;
   default:;
  endcase
 end
 // Sticky semantic failures are reported only after header CRC, as before.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin file_bad_s0<=0;file_bad_s1<=0;record_bad<=0;is_60fps<=0;end
  else begin
   if(state==IDLE&&start_valid)begin file_bad_s0<=0;file_bad_s1<=0;record_bad<=0;is_60fps<=0;end
   if(take&&state==FILE_HEADER)case(header_index)
    9'd0:begin if(byte_data!=8'h42)file_bad_s0<=1; if(byte_data!=8'h42)file_bad_s1<=1;end
    9'd1:begin if(byte_data!=8'h53)file_bad_s0<=1; if(byte_data!=8'h53)file_bad_s1<=1;end
    9'd2:begin if(byte_data!=8'h54)file_bad_s0<=1; if(byte_data!=8'h54)file_bad_s1<=1;end
    9'd3:begin if(byte_data!=8'h52)file_bad_s0<=1; if(byte_data!=8'h52)file_bad_s1<=1;end
    9'd4:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h01)file_bad_s1<=1;end
    9'd5:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd6:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd7:begin if(byte_data!=8'h02)file_bad_s0<=1; if(byte_data!=8'h02)file_bad_s1<=1;end
    9'd12:begin if(byte_data!=8'h18&&byte_data!=8'h3c)begin file_bad_s0<=1;file_bad_s1<=1;end is_60fps<=(byte_data==8'h3c);end
    9'd13:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd14:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd15:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd16:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h01)file_bad_s1<=1;end
    9'd17:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd18:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd19:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd20:begin if(byte_data!=8'h80)file_bad_s0<=1; if(byte_data!=8'h80)file_bad_s1<=1;end
    9'd21:begin if(byte_data!=8'hbb)file_bad_s0<=1; if(byte_data!=8'hbb)file_bad_s1<=1;end
    9'd22:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd23:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd24:begin if(byte_data!=8'h02)file_bad_s0<=1; if(byte_data!=8'h02)file_bad_s1<=1;end
    9'd25:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd26:begin if(byte_data!=8'h10)file_bad_s0<=1; if(byte_data!=8'h10)file_bad_s1<=1;end
    9'd27:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd28:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h01)file_bad_s1<=1;end
    9'd29:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd30:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd31:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd36:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd37:begin if(byte_data!=8'h02)file_bad_s0<=1; if(byte_data!=8'h02)file_bad_s1<=1;end
    9'd38:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd39:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd40:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h80)file_bad_s1<=1;end
    9'd41:begin if(byte_data!=8'hc2)file_bad_s0<=1; if(byte_data!=8'hf4)file_bad_s1<=1;end
    9'd42:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h03)file_bad_s1<=1;end
    9'd43:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd44:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd45:begin if(byte_data!=8'hc2)file_bad_s0<=1; if(byte_data!=8'hf6)file_bad_s1<=1;end
    9'd46:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h03)file_bad_s1<=1;end
    9'd47:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd48:begin if(is_60fps?(byte_data!=8'h20):(byte_data!=8'hd0))begin file_bad_s0<=1;file_bad_s1<=1;end end
    9'd49:begin if(is_60fps?(byte_data!=8'h03):(byte_data!=8'h07))begin file_bad_s0<=1;file_bad_s1<=1;end end
    9'd50:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd51:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd52:begin if(is_60fps?(byte_data!=8'h80):(byte_data!=8'h40))begin file_bad_s0<=1;file_bad_s1<=1;end end
    9'd53:begin if(is_60fps?(byte_data!=8'h0c):(byte_data!=8'h1f))begin file_bad_s0<=1;file_bad_s1<=1;end end
    9'd54:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd55:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd56:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd57:begin if(byte_data!=8'h20)file_bad_s0<=1; if(byte_data!=8'h20)file_bad_s1<=1;end
    9'd58:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd59:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd60:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    9'd61:begin if(byte_data!=8'he4)file_bad_s0<=1; if(byte_data!=8'h18)file_bad_s1<=1;end
    9'd62:begin if(byte_data!=8'h01)file_bad_s0<=1; if(byte_data!=8'h04)file_bad_s1<=1;end
    9'd63:begin if(byte_data!=8'h00)file_bad_s0<=1; if(byte_data!=8'h00)file_bad_s1<=1;end
    default:;
   endcase
   if(take&&state==RECORD_HEADER)begin
    if(header_index==0)record_bad<=0;
    case(header_index)
     9'd0:if(byte_data!=8'h46)record_bad<=1;
     9'd1:if(byte_data!=8'h52)record_bad<=1;
     9'd2:if(byte_data!=8'h4d)record_bad<=1;
     9'd3:if(byte_data!=8'h31)record_bad<=1;
     9'd4:if(byte_data!=record_index[0+:8])record_bad<=1;
     9'd5:if(byte_data!=record_index[8+:8])record_bad<=1;
     9'd6:if(byte_data!=record_index[16+:8])record_bad<=1;
     9'd7:if(byte_data!=record_index[24+:8])record_bad<=1;
     9'd24:if(byte_data!=video_bytes[0+:8])record_bad<=1;
     9'd25:if(byte_data!=video_bytes[8+:8])record_bad<=1;
     9'd26:if(byte_data!={5'd0,video_bytes[18:16]})record_bad<=1;
     9'd27:if(byte_data!=8'd0)record_bad<=1;
     9'd28:if(is_60fps?(byte_data!=8'h80):(byte_data!=8'h40))record_bad<=1;
     9'd29:if(is_60fps?(byte_data!=8'h0c):(byte_data!=8'h1f))record_bad<=1;
     9'd30:if(byte_data!=8'h00)record_bad<=1;
     9'd31:if(byte_data!=8'h00)record_bad<=1;
     9'd32:if(byte_data!=8'd0)record_bad<=1;
     9'd33:if(byte_data!=8'd0)record_bad<=1;
     9'd34:if(byte_data!=8'd0)record_bad<=1;
     9'd35:if(byte_data!=8'd0)record_bad<=1;
     default:;
    endcase
   end
  end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;size<=0;position<=0;header_index<=0;header_crc<=32'hffffffff;stored_crc<=0;
   reserved_nonzero<=0;closed<=0;allocated<=0;video_bytes<=0;video_padded<=0;payload_index<=0;
   video_crc<=32'hffffffff;audio_crc<=32'hffffffff;lane<=0;assembly<=0;row<=0;column<=0;audio_word<=0;
   length_sectors<=0;term_sectors<=0;length_bits<=0;length_step<=0;
   file_header_valid<=0;record_index<=0;video_valid<=0;video_offset<=0;video_data<=0;
   audio_valid<=0;audio_offset<=0;audio_data<=0;record_abort<=0;error_code<=0;
  end else begin
   record_abort<=0;file_header_valid<=0;
   if(video_valid&&video_ready)video_valid<=0;
   if(audio_valid&&audio_ready)audio_valid<=0;
   if(take)position<=position+1'b1;
   if(source_done_valid&&source_done_ready)closed<=1;
   case(state)
    IDLE:if(start_valid)begin
     size<=file_size;position<=0;closed<=0;allocated<=0;error_code<=0;
     record_index<=0;header_index<=0;header_crc<=32'hffffffff;stored_crc<=0;reserved_nonzero<=0;
     state<=FILE_HEADER;
    end
    FILE_HEADER,RECORD_HEADER:if(take)begin
     if(header_index<508)header_crc<=shared_crc;
     else stored_crc[(header_index-508)*8+:8]<=byte_data;
     if(header_index<508&&header_index>=(state==FILE_HEADER?64:36)&&byte_data!=0)reserved_nonzero<=1;
     if(header_index==511)begin header_index<=0;state<=state==FILE_HEADER?FILE_CHECK:RECORD_CHECK;end
     else header_index<=header_index+1'b1;
    end
    FILE_CHECK:begin
     if((header_crc^32'hffffffff)!=stored_crc)fail(2);
     else if(reserved_nonzero||!((width==320&&height==180)||s1)||
      (s1?file_bad_s1:file_bad_s0))fail(3);
     else if(frame_count==0||size<512)fail(4);
     else begin
      video_bytes<=s1?259200:115200;video_padded<=s1?259584:115200;
      length_sectors<=42'd1;term_sectors<=s1?42'd524:42'd242;length_bits<=frame_count;length_step<=0;state<=LENGTH;
     end
    end
    LENGTH:begin
     // Exact sector count: original512+frame_count*(123904 or268288).
     // All terms are multiples of512. For every32-bit frame_count:
     // 1+524*(2^32-1)<2^42 and524*2^32<2^42.
     // Thus42-bit accum/term cannot overflow during any of32 rounds.
     if(length_bits[0])length_sectors<=length_sectors+term_sectors;
     term_sectors<=term_sectors<<1;length_bits<=length_bits>>1;
     if(length_step==31)state<=LENGTH_CHECK;else length_step<=length_step+1'b1;
    end
    LENGTH_CHECK:if((|size[8:0])||length_sectors!={19'd0,size[31:9]})fail(4);
     else begin
      file_header_valid<=1;header_index<=0;header_crc<=32'hffffffff;stored_crc<=0;reserved_nonzero<=0;state<=RECORD_HEADER;
     end
    RECORD_CHECK:begin
     if((header_crc^32'hffffffff)!=stored_crc)fail(5);
     else if(reserved_nonzero||record_bad||record_pts!=expected_record_pts)fail(6);
     else state<=RESERVE;
    end
    RESERVE:if(record_valid&&record_ready)begin
     allocated<=1;payload_index<=0;lane<=0;assembly<=0;row<=0;column<=0;audio_word<=0;
     video_crc<=32'hffffffff;audio_crc<=32'hffffffff;state<=VIDEO;
    end
    VIDEO:if(take)begin
     if(payload_index<video_bytes)begin
      video_crc<=shared_crc;assembly[lane*8+:8]<=byte_data;
      if(lane==3)begin
       video_valid<=1;video_data<={byte_data,assembly[23:0]};video_offset<={row,column};lane<=0;
       if({8'd0,column}+16'd1==(width>>1))begin column<=0;row<=row+1'b1;end else column<=column+1'b1;
      end else lane<=lane+1'b1;
     end else if(byte_data!=0)fail(9);
     if(payload_index==video_padded-1)begin payload_index<=0;lane<=0;assembly<=0;state<=AUDIO;end
     else payload_index<=payload_index+1'b1;
    end
    AUDIO:if(take)begin
     if(payload_index<(is_60fps?19'd3200:19'd8000))begin
      audio_crc<=shared_crc;assembly[lane*8+:8]<=byte_data;
      if(lane==3)begin
       audio_valid<=1;audio_data<={byte_data,assembly[23:0]};audio_offset<=audio_word;
       audio_word<=audio_word+1'b1;lane<=0;
      end else lane<=lane+1'b1;
     end else if(byte_data!=0)fail(9);
     if(payload_index==8191)begin payload_index<=0;state<=VERIFY;end
     else payload_index<=payload_index+1'b1;
    end
    VERIFY:if((video_crc^32'hffffffff)!=record_values[64+:32])fail(7);
     else if((audio_crc^32'hffffffff)!=record_values[96+:32])fail(8);
     else state<=COMMIT;
    COMMIT:if(commit_valid&&commit_ready)begin
     allocated<=0;
     if(record_index==frame_count-1)state<=FINISH;
     else begin
      record_index<=record_index+1'b1;header_index<=0;header_crc<=32'hffffffff;stored_crc<=0;
      reserved_nonzero<=0;state<=RECORD_HEADER;
     end
    end
    FINISH:if(closed)state<=RESULT;
    DRAIN:if(closed)state<=RESULT;
    RESULT:if(done_ready)state<=IDLE;
    default:fail(12);
   endcase
   // Dominant transport/cancel failures cannot publish a concurrently reserved record.
   if(cancel&&state!=IDLE&&state!=RESULT&&state!=DRAIN)fail(11);
   else if(source_done_valid&&source_done_ready&&source_done_error)fail(1);
   else if(closed&&position!=size&&error_code==0)fail(10);
   else if(closed&&(state==FILE_HEADER||state==RECORD_HEADER||state==VIDEO||state==AUDIO)&&error_code==0)fail(10);
   else if(error_code!=0&&state!=IDLE&&state!=DRAIN&&state!=RESULT)fail(error_code);
   else if(take&&(position>=size||byte_last!=(position==size-1))&&error_code==0)fail(10);
  end
 end
endmodule
