`timescale 1ns/1ps
// Packed RGB565 surfaces and a committed stereo-PCM ring in32-bit word SDRAM.
// Adapted transaction policy from av_sdram_queues_r20; source module is unchanged.
// Retry/reset MUST first cancel/drain all attached memory transactions.
module station_record_writer #(
 parameter [20:0] SURFACE0=21'h00000,SURFACE1=21'h12000,PCM_BASE=21'h28000,
 parameter integer PCM_AW=15,MAX_OUTSTANDING=16
)(input wire clk,rst_n,mem_initialized,
 input wire [11:0] audio_samples_per_frame,
 input wire record_valid,output wire record_ready,input wire [15:0] width,height,
 input wire [31:0] record_index,input wire [63:0] record_pts,
 input wire video_valid,output wire video_ready,input wire [16:0] video_offset,input wire [31:0] video_data,
 input wire audio_valid,output wire audio_ready,input wire [10:0] audio_offset,input wire [31:0] audio_data,
 input wire commit_valid,output wire commit_ready,input wire record_abort,
 output wire frame_valid,input wire frame_ready,output wire frame_slot,
 output wire [31:0] frame_index,output wire [63:0] frame_pts,output wire [15:0] frame_width,frame_height,
 input wire release_valid,input wire release_slot,
 output wire pcm_available,output wire [PCM_AW:0] pcm_words_used,
 output wire [20:0] pcm_read_address,input wire pcm_read_advance,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error,
 output wire [1:0] surface_busy,output wire memory_quiet,output reg fault
);
 reg receiving,slot;reg [1:0] busy,queued;
 reg [15:0] active_width,active_height;reg [31:0] active_index;reg [63:0] active_pts;
 reg [16:0] expected_video,video_words;reg [11:0] audio_words;
 reg [8:0] row;reg [7:0] column;reg [PCM_AW:0] audio_wp,audio_rp;
 reg [7:0] writes_pending;
 reg queue_wp,queue_rp;reg [1:0] queue_count;
 reg queue_slot[0:1];reg [31:0] queue_index[0:1];reg [63:0] queue_pts[0:1];
 reg [15:0] queue_width[0:1],queue_height[0:1];
 wire geometry=(width==320&&height==180)||(width==480&&height==270);
 wire [PCM_AW:0] used=audio_wp-audio_rp;
 wire [PCM_AW:0] capacity={1'b1,{PCM_AW{1'b0}}};
 wire [11:0] expected_audio = (audio_samples_per_frame != 0) ? audio_samples_per_frame : 12'd2000;
 assign pcm_words_used=used;assign pcm_available=rst_n&&!fault&&used!=0;
 assign pcm_read_address=PCM_BASE+audio_rp[PCM_AW-1:0];
 assign surface_busy=busy;
 assign record_ready=rst_n&&!fault&&mem_initialized&&!receiving&&geometry&&busy!=3&&used<=capacity-{4'd0,expected_audio};
 wire begin_record=record_valid&&record_ready;
 wire video_legal=video_offset=={row,column}&&video_words<expected_video;
 wire audio_legal=audio_offset==audio_words&&audio_words<expected_audio;
 wire can_write=rst_n&&!fault&&!record_abort&&receiving&&writes_pending<MAX_OUTSTANDING;
 assign mem_wr_valid=can_write&&(video_valid?video_legal:(audio_valid&&audio_legal));
 assign video_ready=can_write&&mem_wr_ready&&video_legal;
 assign audio_ready=can_write&&mem_wr_ready&&!video_valid&&audio_legal;
 wire video_take=video_valid&&video_ready,audio_take=audio_valid&&audio_ready;
 wire write_take=mem_wr_valid&&mem_wr_ready;
 wire [PCM_AW-1:0] audio_address=audio_wp[PCM_AW-1:0]+audio_offset;
 assign mem_wr_address=video_valid?(slot?SURFACE1:SURFACE0)+video_offset:PCM_BASE+audio_address;
 assign mem_wr_data=video_valid?video_data:audio_data;
 assign mem_wr_rsp_ready=rst_n;
 wire ack=mem_wr_rsp_valid&&mem_wr_rsp_ready;
 assign memory_quiet=writes_pending==0&&!mem_wr_valid;
 wire counts_ok=video_words==expected_video&&audio_words==expected_audio;
 assign commit_ready=rst_n&&!fault&&receiving&&counts_ok&&writes_pending==0&&!record_abort&&!mem_wr_rsp_valid;
 wire commit=commit_valid&&commit_ready;
 assign frame_valid=rst_n&&!fault&&queue_count!=0;
 assign frame_slot=queue_slot[queue_rp];assign frame_index=queue_index[queue_rp];assign frame_pts=queue_pts[queue_rp];
 assign frame_width=queue_width[queue_rp];assign frame_height=queue_height[queue_rp];
 wire frame_take=frame_valid&&frame_ready;
 wire release_ok=release_valid&&busy[release_slot]&&!(receiving&&slot==release_slot)&&
  (!queued[release_slot]||(frame_take&&frame_slot==release_slot));
 wire [1:0] release_mask=release_ok?(release_slot?2'b10:2'b01):2'b00;
 wire [1:0] begin_mask=begin_record?(!busy[0]?2'b01:2'b10):2'b00;
 wire [1:0] take_mask=frame_take?(frame_slot?2'b10:2'b01):2'b00;
 wire [1:0] commit_mask=commit?(slot?2'b10:2'b01):2'b00;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   receiving<=0;slot<=0;busy<=0;queued<=0;active_width<=0;active_height<=0;active_index<=0;active_pts<=0;
   expected_video<=0;video_words<=0;audio_words<=0;row<=0;column<=0;audio_wp<=0;audio_rp<=0;
   writes_pending<=0;queue_wp<=0;queue_rp<=0;queue_count<=0;fault<=0;
  end else begin
   if(record_abort||(record_valid&&!receiving&&!geometry)||
    (ack&&(mem_wr_rsp_error||(writes_pending==0&&!write_take)))||
    (release_valid&&!release_ok)||(pcm_read_advance&&(!pcm_available))||
    (commit_valid&&receiving&&writes_pending==0&&!counts_ok))fault<=1;
   if(can_write&&video_valid&&!video_legal)fault<=1;
   if(can_write&&!video_valid&&audio_valid&&!audio_legal)fault<=1;
   case({write_take,ack})
    2'b10:writes_pending<=writes_pending+1'b1;
    2'b01:if(writes_pending!=0)writes_pending<=writes_pending-1'b1;
    default:;
   endcase
   if(!fault)begin
    busy<=(busy&~release_mask)|begin_mask;
    queued<=(queued&~take_mask)|commit_mask;
    if(begin_record)begin
     receiving<=1;slot<=busy[0];active_width<=width;active_height<=height;active_index<=record_index;active_pts<=record_pts;
     expected_video<=width==480?64800:28800;video_words<=0;audio_words<=0;row<=0;column<=0;
    end
    if(video_take)begin
     video_words<=video_words+1'b1;
     if({8'd0,column}+16'd1==(active_width>>1))begin column<=0;row<=row+1'b1;end
     else column<=column+1'b1;
    end
    if(audio_take)audio_words<=audio_words+1'b1;
    if(commit)begin
     receiving<=0;audio_wp<=audio_wp+expected_audio;
     queue_slot[queue_wp]<=slot;queue_index[queue_wp]<=active_index;queue_pts[queue_wp]<=active_pts;
     queue_width[queue_wp]<=active_width;queue_height[queue_wp]<=active_height;queue_wp<=!queue_wp;
    end
    if(pcm_read_advance&&pcm_available)audio_rp<=audio_rp+1'b1;
    if(frame_take)queue_rp<=!queue_rp;
    case({commit,frame_take})2'b10:queue_count<=queue_count+1'b1;2'b01:queue_count<=queue_count-1'b1;default:;endcase
   end
  end
 end
endmodule
