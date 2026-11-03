`timescale 1ns/1ps
// Complete abstract video path: file bytes + acknowledged memory transactions
// -> R56 AV playback -> dual-clock line banks -> scaled 720p RGB/sync.
// External clocks/SD/FAT/SDRAM/HDMI PHY are still required; not a board pin top.
module station_video_display #(
 parameter integer MEDIA_VIEWPORT=0,PCM_AW=15,FIFO_AW=10,FIFO_DEPTH=1024,FIFO_PREFILL=128
)(
 input wire bus_clk,pixel_clk,arst_n,enabled,paused,cancel,mem_initialized,
 input wire physical_tick,
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
 output wire control_frame_commit,
 output wire memory_quiet,output wire [23:0] out_rgb,output wire [11:0] out_x,out_y,
 output wire out_de,out_hs,out_vs,output wire pixel_fault,output wire [31:0] underflow_lines
);
 wire brst,prst;
 reset_sync br(.clk(bus_clk),.arst_n(arst_n),.rst_n(brst));
 reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 wire frame_boundary,pixel_swap_safe,display_valid,display_slot,publish,rebuffering,playback_fault,bridge_fault;
 wire [15:0] display_width,display_height;
 wire row_valid,row_ready,word_valid,line_done,line_rejected;
 wire [8:0] row,line_row;wire [63:0] row_pts,line_pts;
 wire [7:0] word_index;wire [31:0] word_data;
 wire [11:0] x,y;wire de,hs,vs,frame_start,vblank_start;
 assign fault=playback_fault||bridge_fault;
 assign control_frame_commit=frame_boundary;
 station_video_playback #(.PCM_AW(PCM_AW),.FIFO_AW(FIFO_AW),.FIFO_DEPTH(FIFO_DEPTH),.FIFO_PREFILL(FIFO_PREFILL)) playback(
  .clk(bus_clk),.rst_n(brst),.enabled(enabled),.paused(paused),.cancel(cancel||bridge_fault),.mem_initialized(mem_initialized),
  .physical_tick(physical_tick),.frame_boundary(frame_boundary),.pixel_swap_safe(pixel_swap_safe),
  .file_request(file_request),.file_start_valid(file_start_valid),.file_size(file_size),
  .byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .file_cancel(file_cancel),.files_completed(files_completed),.fault(playback_fault),.file_error(file_error),
  .sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),.content_pop(content_pop),.content_samples(content_samples),
  .display_valid(display_valid),.display_slot(display_slot),.display_pts(display_pts),
  .display_width(display_width),.display_height(display_height),.publish(publish),.rebuffering(rebuffering),
  .row_valid(row_valid),.row_ready(row_ready),.row(row),.row_pts(row_pts),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),
  .line_done(line_done),.line_rejected(line_rejected),.line_row(line_row),.line_pts(line_pts),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error),
  .mem_rd_valid(mem_rd_valid),.mem_rd_ready(mem_rd_ready),.mem_rd_address(mem_rd_address),
  .mem_rd_data_valid(mem_rd_data_valid),.mem_rd_data(mem_rd_data),.mem_rd_last(mem_rd_last),.memory_quiet(memory_quiet));
 station_video_timing timing(.pixel_clk(pixel_clk),.rst_n(prst),.x(x),.y(y),.de(de),.hs(hs),.vs(vs),.frame_start(frame_start),.vblank_start(vblank_start));
 station_video_pixel_bridge #(.MEDIA_VIEWPORT(MEDIA_VIEWPORT)) bridge(
  .bus_clk(bus_clk),.pixel_clk(pixel_clk),.arst_n(arst_n),
  .display_valid(display_valid),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),
  .frame_boundary(frame_boundary),.pixel_swap_safe(pixel_swap_safe),
  .row_valid(row_valid),.row_ready(row_ready),.row(row),.row_pts(row_pts),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),
  .line_done(line_done),.line_rejected(line_rejected),.line_row(line_row),.line_pts(line_pts),
  .line_fault(playback_fault),.bus_fault(bridge_fault),
  .x(x),.y(y),.de(de),.hs(hs),.vs(vs),.vblank_start(vblank_start),
  .out_rgb(out_rgb),.out_x(out_x),.out_y(out_y),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),
  .pixel_fault(pixel_fault),.underflow_lines(underflow_lines));
endmodule
