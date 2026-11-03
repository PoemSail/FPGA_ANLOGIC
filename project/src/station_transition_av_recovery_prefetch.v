// Global-recovery derivative; tested predecessor preserved.
// Recovery branch: persistent timing/UI commits, common media-only reset.
// Transition-stack derivative; verified predecessor preserved.
`timescale 1ns/1ps
// R56 ingest/timeline/PCM plus acknowledged photo descriptors through ONE
// shared visual path. Memory writes are unchanged; PCM and visual BL8 reads
// share the existing audio-priority arbiter. External memory and HDMI required.
module station_transition_av_recovery_prefetch #(
 parameter integer PCM_AW=15,FIFO_AW=10,FIFO_DEPTH=1024,FIFO_PREFILL=128
)(
 input wire bus_clk,pixel_clk,arst_n,media_arst_n,enabled,allow_visual_fetch,paused,cancel,mem_initialized,memory_fault,
 input wire physical_tick,request_photo,effect_enable,input wire [1:0] transition_mode,
 input wire descriptor_valid,output wire descriptor_ready,input wire descriptor_error,
 input wire [20:0] descriptor_base,input wire descriptor_slot,input wire [15:0] descriptor_generation,
 output wire release_valid,release_slot,output wire [15:0] release_generation,
 output wire selected_photo,front_valid,front_slot,output wire [15:0] front_generation,
 output wire pending_valid,load_error,
 output wire file_request,input wire file_start_valid,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire file_cancel,output wire [31:0] files_completed,output wire fault,output wire [3:0] file_error,
 output wire sample_valid,output wire signed [15:0] sample_left,sample_right,
 output wire content_pop,output wire [63:0] content_samples,display_pts,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error,
 output wire mem_rd_valid,input wire mem_rd_ready,output wire [20:0] mem_rd_address,
 input wire mem_rd_data_valid,input wire [31:0] mem_rd_data,input wire mem_rd_last,
 output wire control_frame_commit,memory_quiet,visual_idle,video_prefilled,output wire [23:0] out_rgb,output wire [11:0] out_x,out_y,
 output wire out_de,out_hs,out_vs,output wire pixel_fault,output wire [31:0] underflow_lines
);
 wire brst,prst;reset_sync br(.clk(bus_clk),.arst_n(arst_n&&media_arst_n),.rst_n(brst));
 reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 wire frame_boundary,swap_safe,display_valid,display_slot,publish,rebuffering,playback_fault,visual_fault,line_idle;
 wire visual_rd_valid,visual_rd_ready,visual_data_valid,visual_last;wire [20:0] visual_rd_address;wire [31:0] visual_data;
 wire [15:0] display_width,display_height;wire [11:0] x,y;wire de,hs,vs,fs,vbs;
 assign fault=playback_fault||visual_fault;
 assign visual_idle=line_idle;
 // video_prefilled comes from producer readiness, before timeline publication.
 wire [23:0] resettable_rgb;
 station_recovery_raster_guard persistent_raster(.bus_clk(bus_clk),.pixel_clk(pixel_clk),
  .global_arst_n(arst_n),.media_arst_n(media_arst_n),.x(x),.y(y),.de(de),.hs(hs),.vs(vs),.vblank_start(vbs),
  .media_rgb(resettable_rgb),.out_x(out_x),.out_y(out_y),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),
  .out_rgb(out_rgb),.business_frame_commit(control_frame_commit),.media_pixels_enabled());
 station_shared_video_playback_recovery #(.PCM_AW(PCM_AW),.FIFO_AW(FIFO_AW),.FIFO_DEPTH(FIFO_DEPTH),.FIFO_PREFILL(FIFO_PREFILL)) playback(
  .clk(bus_clk),.rst_n(brst),.enabled(enabled),.paused(paused||request_photo),.cancel(cancel||visual_fault),.mem_initialized(mem_initialized),
  .physical_tick(physical_tick),.frame_boundary(frame_boundary),.pixel_swap_safe(swap_safe),
  .file_request(file_request),.file_start_valid(file_start_valid),.file_size(file_size),
  .byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .file_cancel(file_cancel),.files_completed(files_completed),.fault(playback_fault),.file_error(file_error),
  .sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),.content_pop(content_pop),.content_samples(content_samples),
  .display_valid(display_valid),.display_slot(display_slot),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),.publish(publish),.rebuffering(rebuffering),
  .visual_rd_valid(visual_rd_valid),.visual_rd_ready(visual_rd_ready),.visual_rd_address(visual_rd_address),
  .visual_data_valid(visual_data_valid),.visual_data(visual_data),.visual_last(visual_last),.visual_idle(line_idle),.visual_fault(visual_fault),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error),
  .mem_rd_valid(mem_rd_valid),.mem_rd_ready(mem_rd_ready),.mem_rd_address(mem_rd_address),.mem_rd_data_valid(mem_rd_data_valid),.mem_rd_data(mem_rd_data),.mem_rd_last(mem_rd_last),.memory_quiet(memory_quiet),.prefetch_ready(video_prefilled));
 station_video_timing timing(.pixel_clk(pixel_clk),.rst_n(prst),.x(x),.y(y),.de(de),.hs(hs),.vs(vs),.frame_start(fs),.vblank_start(vbs));
 station_transition_display_banked visual(.bus_clk(bus_clk),.pixel_clk(pixel_clk),.arst_n(arst_n&&media_arst_n),.enabled(enabled&&allow_visual_fetch),.memory_fault(memory_fault||playback_fault),.request_photo(request_photo),
  .effect_enable(effect_enable),.transition_mode(transition_mode),.mix_enable(),.mix_mode(),.mix_phase(),
  .descriptor_valid(descriptor_valid),.descriptor_ready(descriptor_ready),.descriptor_error(descriptor_error),.descriptor_base(descriptor_base),.descriptor_slot(descriptor_slot),.descriptor_generation(descriptor_generation),
  .release_valid(release_valid),.release_slot(release_slot),.release_generation(release_generation),
  .video_valid(display_valid),.video_slot(display_slot),.video_publish(publish),.video_pts(display_pts),.video_width(display_width),.video_height(display_height),
  .frame_boundary(frame_boundary),.pixel_swap_safe(swap_safe),.line_idle(line_idle),.selected_photo(selected_photo),.front_valid(front_valid),.front_slot(front_slot),.front_generation(front_generation),
  .pending_valid(pending_valid),.load_error(load_error),.fault(visual_fault),.pixel_fault(pixel_fault),.underflow_lines(underflow_lines),
  .rd_valid(visual_rd_valid),.rd_ready(visual_rd_ready),.rd_address(visual_rd_address),.rd_data_valid(visual_data_valid),.rd_data(visual_data),.rd_last(visual_last),
  .x(x),.y(y),.de(de),.hs(hs),.vs(vs),.vblank_start(vbs),.out_rgb(resettable_rgb),.out_x(),.out_y(),.out_de(),.out_hs(),.out_vs());
endmodule
