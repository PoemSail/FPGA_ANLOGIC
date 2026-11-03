`timescale 1ns/1ps
// Byte/file service to acknowledged SDRAM writes and committed AV metadata.
module station_r56_ingest #(parameter integer PCM_AW=15,USE_PTS_BASE=0)(
 input wire clk,rst_n,mem_initialized,input wire start_valid,output wire start_ready,input wire [31:0] file_size,
 input wire [63:0] file_pts_base,output wire file_header_valid,output wire [31:0] file_frame_count,
 output wire [11:0] audio_samples_per_frame,
 input wire cancel,input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire done_valid,input wire done_ready,output wire [3:0] error_code,output wire fault,
 output wire frame_valid,input wire frame_ready,output wire frame_slot,output wire [31:0] frame_index,
 output wire [63:0] frame_pts,output wire [15:0] frame_width,frame_height,
 input wire release_valid,release_slot,
 output wire pcm_available,output wire [PCM_AW:0] pcm_words_used,output wire [20:0] pcm_read_address,input wire pcm_read_advance,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error,
 output wire [1:0] surface_busy,output wire memory_quiet
);
 wire [15:0] w,h;wire [31:0] count,idx;wire [63:0] pts;
 wire rv,rr,vv,vr,av,ar,cv,cr,abort_record,writer_fault;
 wire [16:0] vo;wire [10:0] ao;wire [31:0] vd,ad;
 wire decoder_start_ready;
 // Base must remain stable from start through done; default preserves legacy callers.
 wire [63:0] global_pts=pts+(USE_PTS_BASE?file_pts_base:64'd0);
 assign file_frame_count=count;
 assign start_ready=decoder_start_ready&&!writer_fault;
 assign fault=writer_fault||error_code!=0;
 station_r56_decoder decoder(.clk(clk),.rst_n(rst_n),.start_valid(start_valid&&!writer_fault),.start_ready(decoder_start_ready),
  .file_size(file_size),.cancel(cancel||writer_fault),.byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .file_header_valid(file_header_valid),.width(w),.height(h),.frame_count(count),.audio_samples_per_frame(audio_samples_per_frame),.record_valid(rv),.record_ready(rr),.record_index(idx),.record_pts(pts),
  .video_valid(vv),.video_ready(vr),.video_offset(vo),.video_data(vd),.audio_valid(av),.audio_ready(ar),.audio_offset(ao),.audio_data(ad),
  .commit_valid(cv),.commit_ready(cr),.record_abort(abort_record),.done_valid(done_valid),.done_ready(done_ready),.error_code(error_code));
 station_record_writer #(.PCM_AW(PCM_AW)) writer(.clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.audio_samples_per_frame(audio_samples_per_frame),
  .record_valid(rv),.record_ready(rr),.width(w),.height(h),.record_index(idx),.record_pts(global_pts),
  .video_valid(vv),.video_ready(vr),.video_offset(vo),.video_data(vd),.audio_valid(av),.audio_ready(ar),.audio_offset(ao),.audio_data(ad),
  .commit_valid(cv),.commit_ready(cr),.record_abort(abort_record),
  .frame_valid(frame_valid),.frame_ready(frame_ready),.frame_slot(frame_slot),.frame_index(frame_index),.frame_pts(frame_pts),
  .frame_width(frame_width),.frame_height(frame_height),.release_valid(release_valid),.release_slot(release_slot),
  .pcm_available(pcm_available),.pcm_words_used(pcm_words_used),.pcm_read_address(pcm_read_address),.pcm_read_advance(pcm_read_advance),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error),
  .surface_busy(surface_busy),.memory_quiet(memory_quiet),.fault(writer_fault));
endmodule
