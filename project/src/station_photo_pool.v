`timescale 1ns/1ps
// One BMP loader/scaler, two externally owned destination slots.
// Loader uses BASE0 internally; only target writes are translated for slot1.
// Descriptor handshake transfers ownership to the display/scheduler. It also
// releases the loader's private hold, NOT the allocator's published surface.
module station_photo_pool #(
 parameter [20:0] SOURCE_BASE=21'h80000,BASE0=21'h40000,BASE1=21'h52000
)(
 input wire clk,rst_n,mem_initialized,start_valid,output wire start_ready,
 input wire [31:0] file_size,input wire cancel,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,output wire file_cancel,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,output wire [7:0] error_code,
 output wire [1:0] error_stage,output wire [20:0] descriptor_base,output wire descriptor_slot,output wire [15:0] descriptor_generation,
 input wire release_valid,input wire release_slot,input wire [15:0] release_generation,input wire clear_fault,
 output wire [1:0] busy,published,output wire pool_fault,output wire memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,input wire memory_fault,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 localparam [21:0] END0={1'b0,BASE0}+22'h12000,END1={1'b0,BASE1}+22'h12000,SOURCE_END={1'b0,SOURCE_BASE}+22'hc0000;
 localparam CONFIG_OK=BASE0[7:0]==0&&BASE1[7:0]==0&&SOURCE_BASE[2:0]==0&&
  END0<=22'h200000&&END1<=22'h200000&&SOURCE_END<=22'h200000&&
  (END0<={1'b0,BASE1}||END1<={1'b0,BASE0})&&
  (END0<={1'b0,SOURCE_BASE}||SOURCE_END<={1'b0,BASE0})&&
  (END1<={1'b0,SOURCE_BASE}||SOURCE_END<={1'b0,BASE1});
 reg active,slot,release_loader,mapping_fault;reg [15:0] generation;
 wire alloc_ready,alloc_slot,alloc_fault,lsr,ldv,lde,lwv;wire [15:0] alloc_generation;wire [20:0] alloc_base,lwa;
 wire [7:0] lcode;wire [1:0] lstage;wire [31:0] ldata;
 wire take_start=start_valid&&start_ready,finish=descriptor_valid&&descriptor_ready;
 wire target=lwa>=BASE0&&{1'b0,lwa}<END0;
 wire source=lwa>=SOURCE_BASE&&{1'b0,lwa}<SOURCE_END;
 wire bad_mapping=lwv&&!target&&!source;
 wire [21:0] translated={1'b0,BASE1}+({1'b0,lwa}-{1'b0,BASE0});
 assign start_ready=rst_n&&CONFIG_OK&&!active&&!cancel&&!memory_fault&&lsr&&alloc_ready;
 assign descriptor_valid=rst_n&&active&&ldv;
 assign descriptor_error=lde||mapping_fault;
 assign error_code=lcode!=0?lcode:(mapping_fault?8'he0:8'h00);
 assign error_stage=lstage;assign descriptor_slot=slot;assign descriptor_generation=generation;
 assign descriptor_base=slot?BASE1:BASE0;
 assign pool_fault=alloc_fault||mapping_fault||!CONFIG_OK;
 assign mem_wr_valid=lwv&&!bad_mapping&&!mapping_fault&&CONFIG_OK;
 assign mem_wr_address=slot&&target?translated[20:0]:lwa;assign mem_wr_data=ldata;
 station_photo_allocator #(.BASE0(BASE0),.BASE1(BASE1)) allocator(
  .clk(clk),.rst_n(rst_n),.clear_fault(clear_fault),.reserve_valid(take_start),.reserve_ready(alloc_ready),.reserve_slot(alloc_slot),
  .reserve_generation(alloc_generation),.reserve_base(alloc_base),.complete_valid(finish),.complete_slot(slot),.complete_generation(generation),.complete_error(descriptor_error),
  .release_valid(release_valid),.release_slot(release_slot),.release_generation(release_generation),.busy(busy),.published(published),.fault(alloc_fault));
 station_photo_loader #(.SOURCE_BASE(SOURCE_BASE),.SURFACE_BASE(BASE0)) loader(
  .clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.start_valid(take_start),.start_ready(lsr),.file_size(file_size),.cancel(cancel||mapping_fault),
  .byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),.file_cancel(file_cancel),
  .descriptor_valid(ldv),.descriptor_ready(active&&descriptor_ready),.descriptor_error(lde),.error_code(lcode),.error_stage(lstage),.descriptor_base(),
  .release_surface(release_loader),.memory_quiet(memory_quiet),.rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),
  .rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.memory_fault(memory_fault),
  .mem_wr_valid(lwv),.mem_wr_ready(mem_wr_ready&&!bad_mapping&&!mapping_fault&&CONFIG_OK),.mem_wr_address(lwa),.mem_wr_data(ldata),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin active<=0;slot<=0;generation<=0;release_loader<=0;mapping_fault<=0;end
  else begin
   release_loader<=0;
   if(take_start)begin active<=1;slot<=alloc_slot;generation<=alloc_generation;mapping_fault<=0;end
   if(bad_mapping)mapping_fault<=1;
   if(finish)begin active<=0;release_loader<=!descriptor_error;end
  end
 end
endmodule
