// CONTEXT-ONLY alternative for station_fat_metadata_adapter.v. Never both.
// No307-bit result register: shared service retains result and lease until
// cursor ready/acceptance or local cancel. station_fat_file_cursor is already
// ready in METADATA_WAIT before service result; decoder start/byte stalls do
// not block this handshake. Arbitrary stalled result consumers WOULD hold
// the shared service, unlike the separately retained buffered frontend.
`timescale 1ns/1ps
// Per-file command -> shared-parser lease -> one cache/SD sector -> tagged result.
// rst_n is GLOBAL, not parser-local reset. cancel discards this command only.
// A cancelled unaccepted lease is withdrawn; a lease with no accepted sector is
// closed with synthetic done_error; an accepted sector drains through real done.
// Result layout matches metadata engine: {client2,kind2,generation8,error4,...291}.
// Returned stale/corrupt tags are never forwarded: deliver zero-metadata errorE.
// Client must retain one outstanding command; global reset also resets backend.
module station_fat_metadata_adapter #(
 parameter integer CLIENT_ID=0
)(
 input wire clk,rst_n,cancel,
 input wire command_valid,output wire command_ready,input wire [1:0] command_kind,
 input wire [31:0] command_lba,input wire [87:0] command_short_name,input wire [27:0] command_cluster,
 input wire [31:0] command_volume_start,command_partition_size,input wire command_partitioned,
 output wire result_valid,input wire result_ready,output wire [306:0] result_payload,
 output reg abort_done,protocol_fault,output wire quiet,sector_outstanding,lease_active,
 output wire service_request_valid,input wire service_request_ready,output wire [1:0] service_kind,
 output wire [7:0] service_generation,output wire [87:0] service_short_name,output wire [27:0] service_cluster,
 output wire [31:0] service_volume_start,service_partition_size,output wire service_partitioned,service_cancel,
 output wire service_byte_valid,input wire service_byte_ready,output wire [7:0] service_byte_data,output wire service_byte_last,
 output wire service_done_valid,input wire service_done_ready,output wire service_done_error,
 input wire service_result_valid,output wire service_result_ready,input wire [306:0] service_result_payload,
 output wire block_valid,input wire block_ready,output wire [31:0] block_lba,
 input wire block_data_valid,output wire block_data_ready,input wire [7:0] block_data,input wire block_data_last,
 input wire block_done_valid,output wire block_done_ready,input wire block_done_error
);
 localparam IDLE=0,SEND=1,REQUEST_BLOCK=2,RECEIVE_BLOCK=3,CLOSE_EMPTY=4,WAIT_RESULT=5,HOLD_RESULT=6;
 localparam [1:0] CLIENT=CLIENT_ID;
 reg [2:0] state;reg aborted;
 reg [1:0] kind;reg [7:0] next_generation,generation;reg [31:0] lba,volume_start,partition_size;
 reg [87:0] short_name;reg [27:0] cluster;reg partitioned;
 wire abort_now=aborted||cancel;
 wire tag_ok=service_result_payload[306:305]==CLIENT&&service_result_payload[304:303]==kind&&
  service_result_payload[302:295]==generation;
 assign command_ready=rst_n&&state==IDLE&&!cancel;
 assign result_valid=rst_n&&!abort_now&&(state==HOLD_RESULT||(state==WAIT_RESULT&&service_result_valid));
 assign result_payload=state==HOLD_RESULT?{CLIENT,kind,generation,4'h3,291'd0}:
  (tag_ok?service_result_payload:{CLIENT,kind,generation,4'he,291'd0});
 assign quiet=rst_n&&state==IDLE;
 assign sector_outstanding=rst_n&&state==RECEIVE_BLOCK;
 assign lease_active=rst_n&&(state==REQUEST_BLOCK||state==RECEIVE_BLOCK||state==CLOSE_EMPTY||state==WAIT_RESULT);
 assign service_request_valid=rst_n&&state==SEND&&!abort_now;
 assign service_kind=kind;assign service_generation=generation;assign service_short_name=short_name;
 assign service_cluster=cluster;assign service_volume_start=volume_start;assign service_partition_size=partition_size;assign service_partitioned=partitioned;
 assign service_cancel=lease_active&&abort_now;
 assign block_valid=rst_n&&state==REQUEST_BLOCK&&!abort_now;assign block_lba=lba;
 assign service_byte_valid=rst_n&&state==RECEIVE_BLOCK&&block_data_valid;
 assign service_byte_data=block_data;assign service_byte_last=block_data_last;
 assign block_data_ready=rst_n&&state==RECEIVE_BLOCK&&service_byte_ready;
 assign service_done_valid=rst_n&&(state==CLOSE_EMPTY||(state==RECEIVE_BLOCK&&block_done_valid));
 assign service_done_error=state==CLOSE_EMPTY||block_done_error;
 assign block_done_ready=rst_n&&state==RECEIVE_BLOCK&&service_done_ready;
 assign service_result_ready=rst_n&&state==WAIT_RESULT&&(abort_now||result_ready);
 initial if(CLIENT_ID<0||CLIENT_ID>2)$error("Metadata adapter CLIENT_ID must be0..2");
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;aborted<=0;next_generation<=0;generation<=0;kind<=0;lba<=0;
   volume_start<=0;partition_size<=0;short_name<=0;cluster<=0;partitioned<=0;
   abort_done<=0;protocol_fault<=0;
  end else begin
   abort_done<=0;protocol_fault<=0;
   if(cancel&&state!=IDLE)aborted<=1;
   case(state)
    IDLE:if(command_valid&&command_ready)begin
     kind<=command_kind;generation<=next_generation;next_generation<=next_generation+1'b1;
     lba<=command_lba;short_name<=command_short_name;cluster<=command_cluster;
     volume_start<=command_volume_start;partition_size<=command_partition_size;partitioned<=command_partitioned;aborted<=0;
     if(command_kind==3)state<=HOLD_RESULT;
     else state<=SEND;
    end
    SEND:if(abort_now)begin abort_done<=1;state<=IDLE;end
     else if(service_request_ready)state<=REQUEST_BLOCK;
    REQUEST_BLOCK:if(abort_now)state<=CLOSE_EMPTY;
     else if(block_ready)state<=RECEIVE_BLOCK;
    RECEIVE_BLOCK:if(block_done_valid&&block_done_ready)state<=WAIT_RESULT;
    CLOSE_EMPTY:if(service_done_valid&&service_done_ready)state<=WAIT_RESULT;
    WAIT_RESULT:if(service_result_valid&&service_result_ready)begin
     if(abort_now)begin abort_done<=1;state<=IDLE;end
     else begin
      if(!tag_ok)protocol_fault<=1;
      state<=IDLE;
     end
    end
    HOLD_RESULT:if(cancel)begin abort_done<=1;state<=IDLE;end
     else if(result_ready)state<=IDLE;
    default:begin abort_done<=1;protocol_fault<=1;state<=IDLE;end
   endcase
  end
 end
endmodule
