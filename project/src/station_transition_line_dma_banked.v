`timescale 1ns/1ps
// Shared RGB565 DMA, selecting OLD/CANDIDATE per aligned BL8. No added RAM.
// Capture both bases and transition state on row acceptance. Publication and
// phase changes belong in a drained frame window; row-local capture also
// protects stalled offers from changing descriptors. Common reset required.
module station_transition_line_dma_banked(
 input wire clk,rst_n,enabled,publish,
 input wire display_valid,input wire [20:0] display_base,candidate_base,
 input wire mix_enable,input wire [1:0] mix_mode,input wire [7:0] mix_phase,
 input wire [63:0] display_pts,input wire [15:0] display_width,display_height,
 input wire row_valid,output wire row_ready,input wire [8:0] row,input wire [63:0] row_pts,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire word_valid,output wire [7:0] word_index,output wire [31:0] word_data,
 output wire line_done,line_rejected,output wire [8:0] line_row,output wire [63:0] line_pts,
 output wire idle,output wire fault
);
 reg old_photo,old_slot,new_slot;
 reg held_mix,base_fault;reg [1:0] held_mode;reg [7:0] held_phase;
 wire dma_fault,inner_row_ready;wire [20:0] relative_address;
 // Fixed production layout: video0/1 at0/0x12000, photo0/1
 // at0x40000/0x52000. Other aligned addresses are intentionally rejected.
 wire known_old=display_base==0||display_base==21'h12000||display_base==21'h40000||display_base==21'h52000;
 wire known_new=candidate_base==21'h40000||candidate_base==21'h52000;
 wire valid_mix=!mix_enable||(display_width==480&&display_height==270&&display_base[18]&&
  ((mix_mode==1&&mix_phase<=240&&mix_phase[2:0]==0)||(mix_mode==2&&mix_phase<=4))&&known_new&&candidate_base!=display_base);
 wire valid_base=known_old&&valid_mix;
 wire use_candidate=held_mix&&(held_mode==1?relative_address[7:0]<held_phase:
  (held_phase>=4||{6'b0,relative_address[4:3]}<held_phase));
 wire selected_slot=use_candidate?new_slot:old_slot;
 wire [9:0] bank_row={1'b0,relative_address[16:8]}+(selected_slot?10'd288:10'd0);
 assign fault=dma_fault||base_fault;
 assign row_ready=inner_row_ready&&!base_fault&&valid_base;
 assign rd_address={2'b0,old_photo,bank_row,relative_address[7:0]};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin old_photo<=0;old_slot<=0;new_slot<=0;held_mix<=0;held_mode<=0;held_phase<=0;base_fault<=0;end
  else begin
   if(row_valid&&inner_row_ready&&!valid_base)base_fault<=1;
   if(row_valid&&row_ready)begin
    old_photo<=display_base[18];old_slot<=display_base[16];new_slot<=candidate_base[16];
    held_mix<=mix_enable;held_mode<=mix_mode;held_phase<=mix_phase;
   end
  end
 end
 station_rgb565_line_dma dma(.clk(clk),.rst_n(rst_n),.enabled(enabled&&!base_fault),.publish(publish),
  .display_valid(display_valid),.display_slot(1'b0),.display_pts(display_pts),.display_width(display_width),.display_height(display_height),
  .row_valid(row_valid&&valid_base&&!base_fault),.row_ready(inner_row_ready),.row(row),.row_pts(row_pts),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(relative_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),.line_done(line_done),.line_rejected(line_rejected),
  .line_row(line_row),.line_pts(line_pts),.idle(idle),.fault(dma_fault));
endmodule
