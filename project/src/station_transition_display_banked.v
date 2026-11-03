`timescale 1ns/1ps
// Shared visual read path: video and photo descriptors -> ONE line DMA and
// ONE pair of dual-clock line banks ->960x540 viewport. No duplicated scaler.
// This replaces the visual part of the video frontend/bridge when integrated;
// file/audio/timeline, physical memory, HDMI and slide scheduling are external.
module station_transition_display_banked(
 input wire bus_clk,pixel_clk,arst_n,enabled,memory_fault,request_photo,
 input wire effect_enable,input wire [1:0] transition_mode,
 output wire mix_enable,output wire [1:0] mix_mode,output wire [7:0] mix_phase,
 input wire descriptor_valid,output wire descriptor_ready,input wire descriptor_error,
 input wire [20:0] descriptor_base,input wire descriptor_slot,input wire [15:0] descriptor_generation,
 output wire release_valid,release_slot,output wire [15:0] release_generation,
 input wire video_valid,video_slot,video_publish,input wire [63:0] video_pts,
 input wire [15:0] video_width,video_height,
 output wire frame_boundary,pixel_swap_safe,line_idle,
 output wire selected_photo,front_valid,front_slot,output wire [15:0] front_generation,
 output wire pending_valid,load_error,output wire fault,pixel_fault,output wire [31:0] underflow_lines,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 input wire [11:0] x,y,input wire de,hs,vs,vblank_start,
 output wire [23:0] out_rgb,output wire [11:0] out_x,out_y,output wire out_de,out_hs,out_vs
);
 wire rst_n;reset_sync resetter(.clk(bus_clk),.arst_n(arst_n),.rst_n(rst_n));
 wire display_valid,publish,owner_fault,dma_fault,bridge_fault;
 wire [20:0] display_base,candidate_base;wire [63:0] display_pts;wire [15:0] display_width,display_height;
 wire row_valid,row_ready,word_valid,line_done,line_rejected;
 wire [8:0] row,line_row;wire [63:0] row_pts,line_pts;
 wire [7:0] word_index;wire [31:0] word_data;
 assign fault=owner_fault||dma_fault||bridge_fault;
 station_transition_surface owner(.clk(bus_clk),.rst_n(rst_n),.frame_boundary(frame_boundary),.pixel_swap_safe(pixel_swap_safe),.line_idle(line_idle),
  .request_photo(request_photo),.effect_enable(effect_enable),.transition_mode(transition_mode),.memory_fault(memory_fault||dma_fault||bridge_fault),
  .descriptor_valid(descriptor_valid),.descriptor_ready(descriptor_ready),.descriptor_error(descriptor_error),
  .descriptor_base(descriptor_base),.descriptor_slot(descriptor_slot),.descriptor_generation(descriptor_generation),
  .release_valid(release_valid),.release_slot(release_slot),.release_generation(release_generation),
  .video_valid(video_valid),.video_slot(video_slot),.video_publish(video_publish),.video_pts(video_pts),.video_width(video_width),.video_height(video_height),
  .display_valid(display_valid),.display_base(display_base),.candidate_base(candidate_base),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),.publish(publish),
  .selected_photo(selected_photo),.front_valid(front_valid),.front_slot(front_slot),.front_generation(front_generation),.pending_valid(pending_valid),.load_error(load_error),.fault(owner_fault),.mix_enable(mix_enable),.mix_mode(mix_mode),.mix_phase(mix_phase));
 station_transition_line_dma_banked line_dma(.clk(bus_clk),.rst_n(rst_n),.enabled(enabled&&!fault),.publish(publish),
  .display_valid(display_valid),.display_base(display_base),.candidate_base(candidate_base),.mix_enable(mix_enable&&selected_photo),.mix_mode(mix_mode),.mix_phase(mix_phase),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),
  .row_valid(row_valid),.row_ready(row_ready),.row(row),.row_pts(row_pts),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),.line_done(line_done),.line_rejected(line_rejected),.line_row(line_row),.line_pts(line_pts),.idle(line_idle),.fault(dma_fault));
 station_video_pixel_bridge #(.MEDIA_VIEWPORT(1)) bridge(.bus_clk(bus_clk),.pixel_clk(pixel_clk),.arst_n(arst_n),
  .display_valid(display_valid),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),
  .frame_boundary(frame_boundary),.pixel_swap_safe(pixel_swap_safe),
  .row_valid(row_valid),.row_ready(row_ready),.row(row),.row_pts(row_pts),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),.line_done(line_done),.line_rejected(line_rejected),.line_row(line_row),.line_pts(line_pts),
  .line_fault(memory_fault||dma_fault||owner_fault),.bus_fault(bridge_fault),
  .x(x),.y(y),.de(de),.hs(hs),.vs(vs),.vblank_start(vblank_start),
  .out_rgb(out_rgb),.out_x(out_x),.out_y(out_y),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),.pixel_fault(pixel_fault),.underflow_lines(underflow_lines));
endmodule
