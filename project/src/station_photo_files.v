`timescale 1ns/1ps
// UI request -> selected FAT context -> one-loader/two-slot picture pool.
// Before metadata, cancellation closes the file without starting a decoder.
module station_photo_files(
 input wire clk,rst_n,sd_initialized,file_quiescent,mem_initialized,
 input wire request_valid,output wire request_ready,input wire [1:0] image_index,input wire cancel,
 output wire file_request,output wire file_cancel,output wire [87:0] short_name,
 input wire start_valid,output wire start_ready,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,output wire [7:0] error_code,
 output wire [1:0] error_stage,output wire [20:0] descriptor_base,output wire descriptor_slot,output wire [15:0] descriptor_generation,
 input wire release_valid,input wire release_slot,input wire [15:0] release_generation,input wire clear_fault,
 output wire [1:0] busy,published,output wire pool_fault,output wire memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,input wire memory_fault,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 localparam IDLE=0,OPEN=1,ACTIVE=2,ERROR=3;
 reg [1:0] state,index;reg cancelled;
 wire psr,pfc,pdv,pde;wire [7:0] pcode;wire [1:0] pstage;
 wire aborting=cancel||cancelled||memory_fault;
 assign request_ready=rst_n&&state==IDLE&&sd_initialized&&file_quiescent&&psr&&image_index<3&&!cancel&&!memory_fault;
 assign short_name=index==0?"IMAGE000BMP":index==1?"IMAGE001BMP":"IMAGE002BMP";
 assign file_request=rst_n&&state==OPEN&&!aborting;
 assign file_cancel=rst_n&&((state==OPEN&&aborting)||(state==ACTIVE&&(aborting||pfc)));
 assign start_ready=rst_n&&state==OPEN&&!aborting&&psr;
 assign descriptor_valid=rst_n&&(state==ERROR||(state==ACTIVE&&pdv));
 assign descriptor_error=state==ERROR||pde;
 assign error_code=state==ERROR?8'h08:pcode;
 assign error_stage=state==ERROR?2'd1:pstage;
 station_photo_pool pool(.clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),
  .start_valid(start_valid&&state==OPEN&&!aborting),.start_ready(psr),.file_size(file_size),.cancel(state==ACTIVE&&aborting),
  .byte_valid(byte_valid&&state==ACTIVE),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid&&state==ACTIVE),.source_done_ready(source_done_ready),.source_done_error(source_done_error),.file_cancel(pfc),
  .descriptor_valid(pdv),.descriptor_ready(state==ACTIVE&&descriptor_ready),.descriptor_error(pde),.error_code(pcode),.error_stage(pstage),
  .descriptor_base(descriptor_base),.descriptor_slot(descriptor_slot),.descriptor_generation(descriptor_generation),
  .release_valid(release_valid),.release_slot(release_slot),.release_generation(release_generation),.clear_fault(clear_fault),
  .busy(busy),.published(published),.pool_fault(pool_fault),.memory_quiet(memory_quiet),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.memory_fault(memory_fault),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;index<=0;cancelled<=0;end
  else begin
   if((state==OPEN||state==ACTIVE)&&(cancel||memory_fault))cancelled<=1;
   case(state)
    IDLE:if(request_valid&&request_ready)begin state<=OPEN;index<=image_index;cancelled<=0;end
    OPEN:begin if(start_valid&&start_ready)state<=ACTIVE;else if(aborting&&file_quiescent)state<=ERROR;end
    ACTIVE:if(pdv&&descriptor_ready)state<=IDLE;
    ERROR:if(descriptor_ready)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
