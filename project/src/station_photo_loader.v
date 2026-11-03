`timescale 1ns/1ps
// BMP byte session -> acknowledged canonical scratch -> rendered RGB565 surface.
// Scratch and render writes share one port by phase, never by speculative mux:
// every scratch physical completion drains before the render phase starts.
// Final surface ownership is retained until release_surface. Fixed target base;
// front/candidate allocation and the external file service are not included.
module station_photo_loader #(
 parameter [20:0] SOURCE_BASE=21'h80000,SURFACE_BASE=21'h40000
)(
 input wire clk,rst_n,mem_initialized,start_valid,output wire start_ready,
 input wire [31:0] file_size,input wire cancel,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire file_cancel,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,
 output wire [7:0] error_code,output wire [1:0] error_stage,output wire [20:0] descriptor_base,
 input wire release_surface,output wire memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,input wire memory_fault,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 localparam IDLE=0,LOAD=1,START_RENDER=2,RENDER=3,ERROR=4,HELD=5;
 reg [2:0] state;reg cancelled,faulted;reg [7:0] saved_error;reg [1:0] saved_stage;
 wire aborting=cancel||cancelled||memory_fault||faulted;
 wire ssr,sdv,sde,squiet,sidle,sfc,swv,srr,sbr,sdr;
 wire [7:0] scode;wire [15:0] width,height;wire [19:0] pixels;
 wire [20:0] swa;wire [31:0] swd;
 wire rsr,rdv,rde,rquiet,rwv,rrr;wire [7:0] rcode;wire [20:0] rwa;wire [31:0] rwd;
 wire loading=state==LOAD;
 wire release_scratch=(state==START_RENDER&&aborting)||(state==RENDER&&rdv&&descriptor_ready);
 assign start_ready=rst_n&&state==IDLE&&!cancel&&!memory_fault&&ssr&&rsr;
 assign byte_ready=loading&&sbr;assign source_done_ready=loading&&sdr;
 assign file_cancel=rst_n&&loading&&sfc;
 assign mem_wr_valid=loading?swv:rwv;assign mem_wr_address=loading?swa:rwa;assign mem_wr_data=loading?swd:rwd;
 assign mem_wr_rsp_ready=loading?srr:rrr;
 assign memory_quiet=rst_n&&squiet&&rquiet;
 assign descriptor_valid=rst_n&&(state==ERROR||(state==RENDER&&rdv));
 assign descriptor_error=state==ERROR||(state==RENDER&&(rde||aborting));
 assign error_code=state==ERROR?saved_error:(rcode!=0?rcode:(faulted||memory_fault?8'h05:(cancelled||cancel?8'h02:8'h00)));
 assign error_stage=state==ERROR?saved_stage:(state==RENDER?2'd2:2'd0);
 station_bmp_scratch #(.SCRATCH_BASE(SOURCE_BASE)) scratch(
  .clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.start_valid(start_valid&&start_ready),.start_ready(ssr),
  .file_size(file_size),.cancel(loading&&aborting),.byte_valid(byte_valid&&loading),.byte_ready(sbr),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid&&loading),.source_done_ready(sdr),.source_done_error(source_done_error),.file_cancel(sfc),
  .descriptor_valid(sdv),.descriptor_ready(loading&&squiet),.descriptor_error(sde),.error_code(scode),
  .width(width),.height(height),.total_pixels(pixels),.release_scratch(release_scratch),.idle(sidle),.memory_quiet(squiet),
  .mem_wr_valid(swv),.mem_wr_ready(mem_wr_ready&&loading),.mem_wr_address(swa),.mem_wr_data(swd),
  .mem_wr_rsp_valid(mem_wr_rsp_valid&&loading),.mem_wr_rsp_ready(srr),.mem_wr_rsp_error(mem_wr_rsp_error));
 station_photo_render #(.SOURCE_BASE(SOURCE_BASE),.SURFACE_BASE(SURFACE_BASE)) renderer(
  .clk(clk),.rst_n(rst_n),.mem_initialized(mem_initialized),.start_valid(state==START_RENDER&&!aborting),.start_ready(rsr),
  .source_width(width),.source_height(height),.cancel(state==RENDER&&aborting),
  .descriptor_valid(rdv),.descriptor_ready(state==RENDER&&descriptor_ready),.descriptor_error(rde),.error_code(rcode),
  .descriptor_base(descriptor_base),.release_surface(state==HELD&&release_surface),.memory_quiet(rquiet),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),.rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.memory_fault(memory_fault),
  .mem_wr_valid(rwv),.mem_wr_ready(mem_wr_ready&&!loading),.mem_wr_address(rwa),.mem_wr_data(rwd),
  .mem_wr_rsp_valid(mem_wr_rsp_valid&&!loading),.mem_wr_rsp_ready(rrr),.mem_wr_rsp_error(mem_wr_rsp_error));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;cancelled<=0;faulted<=0;saved_error<=0;saved_stage<=0;end
  else begin
   if(state==LOAD||state==START_RENDER||state==RENDER)begin
    if(cancel)cancelled<=1;if(memory_fault)faulted<=1;
   end
   case(state)
    IDLE:if(start_valid&&start_ready)begin state<=LOAD;cancelled<=0;faulted<=0;saved_error<=0;saved_stage<=0;end
    LOAD:if(sdv&&squiet)begin
     if(sde||aborting)begin saved_error<=scode!=0?scode:(faulted||memory_fault?8'h05:8'h08);saved_stage<=1;state<=ERROR;end
     else state<=START_RENDER;
    end
    START_RENDER:begin
     if(aborting)begin saved_error<=faulted||memory_fault?8'h05:8'h02;saved_stage<=2;state<=ERROR;end
     else if(rsr)state<=RENDER;
    end
    RENDER:if(rdv&&descriptor_ready)state<=descriptor_error?IDLE:HELD;
    ERROR:if(descriptor_ready)state<=IDLE;
    HELD:if(release_surface)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
