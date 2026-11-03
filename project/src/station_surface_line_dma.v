`timescale 1ns/1ps
// Reuses the existing RGB565 DMA with relative slot0 addresses. Capture the
// base on row acceptance; input descriptor changes cannot redirect an in-flight
// burst. Bases are256-word aligned and an entire stride256 surface must fit.
module station_surface_line_dma(
 input wire clk,rst_n,enabled,publish,
 input wire display_valid,input wire [20:0] display_base,input wire [63:0] display_pts,
 input wire [15:0] display_width,display_height,
 input wire row_valid,output wire row_ready,input wire [8:0] row,input wire [63:0] row_pts,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire word_valid,output wire [7:0] word_index,output wire [31:0] word_data,
 output wire line_done,line_rejected,output wire [8:0] line_row,output wire [63:0] line_pts,
 output wire idle,output wire fault
);
 reg [12:0] base_page;reg base_fault;
 wire dma_fault,inner_row_ready;
 wire [20:0] relative_address;
 wire [21:0] surface_end={1'b0,display_base}+({6'b0,display_height}<<8);
 wire valid_base=display_base[7:0]==0&&surface_end<=22'h200000;
 assign fault=dma_fault||base_fault;
 assign row_ready=inner_row_ready&&!base_fault&&valid_base;
 assign rd_address={(base_page+relative_address[20:8]),relative_address[7:0]};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin base_page<=0;base_fault<=0;end
  else begin
   if(row_valid&&inner_row_ready&&!valid_base)base_fault<=1;
   if(row_valid&&row_ready)base_page<=display_base[20:8];
  end
 end
 station_rgb565_line_dma dma(.clk(clk),.rst_n(rst_n),.enabled(enabled&&!base_fault),.publish(publish),
  .display_valid(display_valid),.display_slot(1'b0),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),
  .row_valid(row_valid&&valid_base&&!base_fault),.row_ready(inner_row_ready),.row(row),.row_pts(row_pts),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(relative_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),.line_done(line_done),.line_rejected(line_rejected),
  .line_row(line_row),.line_pts(line_pts),.idle(idle),.fault(dma_fault));
endmodule
