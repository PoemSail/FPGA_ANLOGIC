`timescale 1ns/1ps
// Scratch ownership must already be held. Destination ownership remains held
// after successful descriptor transfer until release_surface. No file service
// or shared-memory arbitration is hidden in this component.
module station_photo_render #(
 parameter [20:0] SOURCE_BASE=21'h80000,SURFACE_BASE=21'h40000
)(
 input wire clk,rst_n,mem_initialized,start_valid,output wire start_ready,
 input wire [15:0] source_width,source_height,input wire cancel,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,output wire [7:0] error_code,
 output wire [20:0] descriptor_base,input wire release_surface,output wire memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,input wire memory_fault,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 wire rr,wr,pv,pr,sd,sdr,abort_writer,read_quiet,write_quiet;wire [17:0] pa;wire [15:0] rgb;wire [3:0] source_error;
 wire start=start_valid&&start_ready;
 assign start_ready=rst_n&&rr&&wr;
 assign memory_quiet=read_quiet&&write_quiet;
 station_photo_resampler #(.SOURCE_BASE(SOURCE_BASE)) resampler(
  .clk(clk),.rst_n(rst_n),.start_valid(start),.start_ready(rr),.source_width(source_width),.source_height(source_height),
  .cancel(cancel||abort_writer),.pixel_valid(pv),.pixel_ready(pr),.pixel_address(pa),.pixel_rgb565(rgb),
  .done_valid(sd),.done_ready(sdr),.error_code(source_error),.memory_quiet(read_quiet),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.memory_fault(memory_fault));
 station_photo_surface #(.SURFACE_BASE(SURFACE_BASE)) surface(
  .clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.start_valid(start),.start_ready(wr),.cancel(cancel),
  .pixel_valid(pv),.pixel_ready(pr),.pixel_address(pa),.pixel_rgb565(rgb),
  .source_done_valid(sd),.source_done_ready(sdr),.source_error(source_error),.cancel_source(abort_writer),
  .descriptor_valid(descriptor_valid),.descriptor_ready(descriptor_ready),.descriptor_error(descriptor_error),.error_code(error_code),
  .descriptor_base(descriptor_base),.release_surface(release_surface),.memory_quiet(write_quiet),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error));
endmodule
