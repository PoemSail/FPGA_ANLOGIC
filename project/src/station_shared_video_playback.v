// Structural derivative: original ingest, file-loop, timeline and PCM behavior retained.
// Only the visual-reader connection changes; original source remains intact.
`timescale 1ns/1ps
// Continuous R56 file loops, acknowledged ingest, circular PCM prefetch,
// source-frame line reads and content-driven AV publication in business clk.
// File service opens VIDEO000.R56 afresh on every file_request/start handshake.
// There is no MP4 decoder, FAT/SD PHY, pixel CDC, HDMI or SDRAM PHY in this unit.
// Retry uses common reset AFTER the file source and memory have drained.
module station_shared_video_playback #(
 parameter integer PCM_AW=15,FIFO_AW=10,FIFO_DEPTH=1024,FIFO_PREFILL=128
)(
 input wire clk,rst_n,enabled,paused,cancel,mem_initialized,
 input wire physical_tick,frame_boundary,pixel_swap_safe,
 output wire file_request,input wire file_start_valid,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire file_cancel,output reg [31:0] files_completed,output reg fault,output wire [3:0] file_error,
 output wire sample_valid,output wire signed [15:0] sample_left,sample_right,
 output wire content_pop,output wire [63:0] content_samples,
 output wire display_valid,display_slot,output wire [63:0] display_pts,
 output reg [15:0] display_width,display_height,output wire publish,rebuffering,
 input wire visual_rd_valid,output wire visual_rd_ready,input wire [20:0] visual_rd_address,
 output wire visual_data_valid,output wire [31:0] visual_data,output wire visual_last,
 input wire visual_idle,visual_fault,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error,
 output wire mem_rd_valid,input wire mem_rd_ready,output wire [20:0] mem_rd_address,
 input wire mem_rd_data_valid,input wire [31:0] mem_rd_data,input wire mem_rd_last,
 output wire memory_quiet
);
 wire start_ready,done,header_valid,ingest_fault,read_fault,timeline_fault;
 wire [31:0] frame_count,frame_index;wire fv,fs,release_valid,release_slot;
 wire [63:0] fp;wire [15:0] fw,fh;wire ring_available,advance,pcm_available;
 wire [PCM_AW:0] used;wire [FIFO_AW:0] fifo_level;wire [20:0] pcm_address;
 wire wr_quiet,rd_quiet,line_idle,play_enable;wire [1:0] surface_busy;
 wire [31:0] audio_starves,video_stalls;
 reg file_active,header_seen,completed_once;reg [63:0] file_base,next_base,span;
 wire start=file_request&&file_start_valid;
 assign file_request=rst_n&&enabled&&!fault&&!cancel&&!file_active&&start_ready;
 assign file_cancel=cancel||fault;
 assign memory_quiet=wr_quiet&&rd_quiet;
 wire [63:0] buffered={{(63-PCM_AW){1'b0}},used}+{{(63-FIFO_AW){1'b0}},fifo_level};
 wire prebuffer_ready=buffered>=4000||(completed_once&&buffered!=0);
 station_r56_ingest #(.PCM_AW(PCM_AW),.USE_PTS_BASE(1)) ingest(
  .clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.start_valid(start),.start_ready(start_ready),
  .file_size(file_size),.file_pts_base(file_base),.file_header_valid(header_valid),.file_frame_count(frame_count),
  .cancel(file_cancel),.byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .done_valid(done),.done_ready(1'b1),.error_code(file_error),.fault(ingest_fault),
  .frame_valid(fv),.frame_ready(publish),.frame_slot(fs),.frame_index(frame_index),.frame_pts(fp),.frame_width(fw),.frame_height(fh),
  .release_valid(release_valid),.release_slot(release_slot),
  .pcm_available(ring_available),.pcm_words_used(used),.pcm_read_address(pcm_address),.pcm_read_advance(advance),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error),
  .surface_busy(surface_busy),.memory_quiet(wr_quiet));
 station_shared_media_reader #(.PCM_AW(PCM_AW),.FIFO_AW(FIFO_AW),.FIFO_DEPTH(FIFO_DEPTH),.FIFO_PREFILL(FIFO_PREFILL)) reader(
  .clk(clk),.rst_n(rst_n),.enabled(enabled&&!fault),.physical_tick(physical_tick),.paused(!play_enable||fault),
  .pcm_words_used(used),.pcm_read_address(pcm_address),.pcm_read_advance(advance),
  .pcm_available(pcm_available),.content_pop(content_pop),.sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
  .fifo_level(fifo_level),
  .visual_rd_valid(visual_rd_valid),.visual_rd_ready(visual_rd_ready),.visual_rd_address(visual_rd_address),
  .visual_data_valid(visual_data_valid),.visual_data(visual_data),.visual_last(visual_last),
  .visual_idle(visual_idle),.visual_fault(visual_fault),.line_idle(line_idle),.memory_quiet(rd_quiet),
  .rd_valid(mem_rd_valid),.rd_ready(mem_rd_ready),.rd_address(mem_rd_address),
  .rd_data_valid(mem_rd_data_valid),.rd_data(mem_rd_data),.rd_last(mem_rd_last),.fault(read_fault));
 station_av_timeline timeline(
  .clk(clk),.rst_n(rst_n),.paused(paused||!enabled||fault),.frame_boundary(frame_boundary),.swap_safe(pixel_swap_safe&&line_idle),
  .prebuffer_ready(prebuffer_ready),.pcm_available(pcm_available),.sample_tick(physical_tick),.sample_taken(content_pop),
  .frame_pending(fv),.frame_slot(fs),.frame_pts(fp),.play_enable(play_enable),.publish(publish),.rebuffering(rebuffering),
  .display_valid(display_valid),.display_slot(display_slot),.display_pts(display_pts),
  .release_valid(release_valid),.release_slot(release_slot),.content_samples(content_samples),
  .audio_starves(audio_starves),.video_stalls(video_stalls),.fault(timeline_fault));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   file_active<=0;header_seen<=0;completed_once<=0;file_base<=0;next_base<=0;span<=0;
   files_completed<=0;fault<=0;display_width<=0;display_height<=0;
  end else begin
   if(ingest_fault||read_fault||timeline_fault||cancel)fault<=1;
   if(start)begin file_active<=1;header_seen<=0;file_base<=next_base;end
   if(header_valid)begin header_seen<=1;span<={32'd0,frame_count}*64'd2000;end
   if(done)begin
    file_active<=0;
    if(file_error!=0||!header_seen)fault<=1;
    else begin
     next_base<=file_base+span;completed_once<=1;
     if(files_completed!=32'hffffffff)files_completed<=files_completed+1'b1;
    end
   end
   if(publish)begin display_width<=fw;display_height<=fh;end
  end
 end
endmodule
