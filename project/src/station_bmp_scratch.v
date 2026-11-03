`timescale 1ns/1ps
// BMP source -> external uncommitted RGB888 scratch, one32-bit word/pixel.
// Descriptor is published only after valid file closure and all physical acks.
// A successful descriptor transfers read ownership; no overwrite until release.
// Caller must cancel/drain file and memory before resetting this module.
module station_bmp_scratch #(
 parameter [20:0] SCRATCH_BASE=21'h80000,
 parameter integer MAX_FILE_BYTES=4194304,MAX_PENDING=16
)(
 input wire clk,rst_n,mem_initialized,
 input wire start_valid,output wire start_ready,input wire [31:0] file_size,input wire cancel,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire file_cancel,
 output wire descriptor_valid,input wire descriptor_ready,output wire descriptor_error,output wire [7:0] error_code,
 output wire [15:0] width,height,output wire [19:0] total_pixels,input wire release_scratch,
 output wire idle,output wire memory_quiet,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam CW=bits_for(MAX_PENDING+1),IDLE=0,ACTIVE=1,REPORT=2,HELD=3;
 reg [1:0] state;reg [CW-1:0] pending;reg [19:0] accepted;reg [3:0] write_error;reg [7:0] result_error;
 wire parser_ready,meta_valid,px_valid,parser_done,parser_error;
 wire [19:0] px_address;wire [23:0] px_rgb;wire [3:0] parser_code;
 wire [21:0] address_sum={1'b0,SCRATCH_BASE}+{2'b0,px_address};
 wire permit=state==ACTIVE&&!cancel&&write_error==0&&!address_sum[21]&&pending<MAX_PENDING;
 assign start_ready=rst_n&&state==IDLE&&mem_initialized&&parser_ready;
 assign file_cancel=rst_n&&(cancel||(state==ACTIVE&&(write_error!=0||parser_error)));
 assign mem_wr_valid=rst_n&&permit&&px_valid;
 assign mem_wr_address=address_sum[20:0];assign mem_wr_data={8'd0,px_rgb};
 assign mem_wr_rsp_ready=rst_n&&state!=IDLE;
 wire put=mem_wr_valid&&mem_wr_ready,ack=mem_wr_rsp_valid&&mem_wr_rsp_ready;
 assign descriptor_valid=rst_n&&state==REPORT;
 assign descriptor_error=result_error!=0||cancel||write_error!=0;
 assign error_code=write_error!=0?{write_error,result_error[3:0]}:(cancel&&result_error==0?8'h08:result_error);
 assign idle=rst_n&&state==IDLE;
 assign memory_quiet=rst_n&&pending==0&&!mem_wr_valid&&!mem_wr_rsp_valid;
 station_bmp_source #(.MAX_FILE_BYTES(MAX_FILE_BYTES)) decoder(
  .clk(clk),.rst_n(rst_n),.start_valid(start_valid&&start_ready),.start_ready(parser_ready),.file_size(file_size),.cancel(file_cancel),
  .byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .meta_valid(meta_valid),.meta_ready(1'b1),.width(width),.height(height),.total_pixels(total_pixels),
  .pixel_valid(px_valid),.pixel_ready(permit&&mem_wr_ready),.pixel_address(px_address),.pixel_rgb(px_rgb),
  .done_valid(parser_done),.done_ready(state==REPORT&&descriptor_ready),.done_error(parser_error),.error_code(parser_code));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;pending<=0;accepted<=0;write_error<=0;result_error<=0;end
  else begin
   case({put,ack})2'b10:pending<=pending+1'b1;2'b01:if(pending!=0)pending<=pending-1'b1;default:;endcase
   if(put)accepted<=accepted+1'b1;
   if(ack&&write_error==0)begin
    if(pending==0)write_error<=1;
    else if(mem_wr_rsp_error)write_error<=2;
   end
   if(state==ACTIVE&&px_valid&&address_sum[21]&&write_error==0)write_error<=4;
   case(state)
    IDLE:if(start_valid&&start_ready)begin state<=ACTIVE;accepted<=0;write_error<=0;result_error<=0;end
    ACTIVE:if(parser_done&&pending==0&&!ack)begin
     result_error<={write_error,parser_code};
     if(write_error==0&&parser_code==0&&accepted!=total_pixels)result_error<=8'h30;
     state<=REPORT;
    end
    REPORT:begin
     if(cancel&&result_error==0)result_error<=8'h08;
     if(descriptor_ready)state<=descriptor_error?IDLE:HELD;
    end
    HELD:if(release_scratch)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
