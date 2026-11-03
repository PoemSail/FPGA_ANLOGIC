`timescale 1ns/1ps
// Cancellable per-file cursor around an EXTERNAL globally reset metadata adapter.
// Metadata and CRC-quarantined file sectors share one cache/backend channel.
// A local cancel resets only the cursor; metadata_cancel stays asserted until
// the consumer closes/abandons the transaction AND metadata_quiet is observed.
// request has the retained context's pulse/held-until-idle contract, no queue.
module station_file_context_shared_metadata #(
 parameter integer MAX_FILE_BYTES=268435456,MAX_CHAIN_CLUSTERS=65536,MAX_DIR_CLUSTERS=512,
 parameter integer NATIVE_HISTORY=0
)(
 input wire clk,rst_n,request,cancel,input wire [87:0] short_name,
 output wire start_valid,input wire start_ready,output wire [31:0] file_size,
 output wire byte_valid,input wire byte_ready,output wire [7:0] byte_data,output wire byte_last,
 output wire source_done_valid,input wire source_done_ready,output wire source_done_error,
 output wire quiescent,output wire [3:0] error_code,
 output wire metadata_valid,input wire metadata_ready,output wire [1:0] metadata_kind,
 output wire [31:0] metadata_lba,output wire [87:0] metadata_short_name,output wire [27:0] metadata_cluster,
 output wire [31:0] metadata_volume_start,metadata_partition_size,output wire metadata_partitioned,
 input wire metadata_result_valid,output wire metadata_result_ready,input wire [306:0] metadata_result_payload,
 output wire metadata_cancel,input wire metadata_quiet,
 input wire metadata_block_valid,output wire metadata_block_ready,input wire [31:0] metadata_block_lba,
 output wire metadata_block_data_valid,input wire metadata_block_data_ready,output wire [7:0] metadata_block_data,
 output wire metadata_block_data_last,metadata_block_done_valid,input wire metadata_block_done_ready,
 output wire metadata_block_done_error,
 output wire block_valid,input wire block_ready,output wire [31:0] block_lba,
 input wire block_data_valid,output wire block_data_ready,input wire [7:0] block_data,input wire block_data_last,
 input wire block_done_valid,output wire block_done_ready,input wire block_done_error
);
 localparam RESET=0,IDLE=1,ACTIVE=2,DRAIN=3,ABORT_RESET=4,ABORT_CLOSE=5;
 reg [2:0] state;reg outstanding,started;reg [3:0] saved_error;
 wire parser_rst=rst_n&&state!=RESET&&state!=ABORT_RESET;
 wire live=rst_n&&state==ACTIVE&&!cancel;
 wire aborting=state==DRAIN||state==ABORT_RESET||state==ABORT_CLOSE||cancel;
 wire metadata_busy=!metadata_quiet;
 wire open_ready,mv,mready,dv,dready,done,done_ready,done_error;
 wire [31:0] size,flba;wire [3:0] ferr;
 wire fv,fr,fdr,fcr,cmdv,cmdr,result_ready;
 assign start_valid=live&&!started&&(mv||done);
 assign file_size=mv?size:32'd0;
 assign mready=start_valid&&start_ready;
 assign byte_valid=live&&started&&dv;
 assign dready=live&&started&&byte_ready;
 assign source_done_valid=rst_n&&((live&&started&&done)||state==ABORT_CLOSE);
 assign source_done_error=state==ABORT_CLOSE||done_error;
 assign done_ready=live&&started&&source_done_ready;
 assign quiescent=rst_n&&state==IDLE&&!outstanding&&metadata_quiet;
 assign error_code=(state==ABORT_RESET||state==ABORT_CLOSE)?4'hf:saved_error;
 assign metadata_valid=live&&cmdv;
 assign cmdr=live&&metadata_ready;
 assign metadata_result_ready=live&&result_ready;
 assign metadata_cancel=rst_n&&aborting;
 // Adapter remains connected throughout local cursor reset and abort closure.
 assign block_valid=rst_n&&(metadata_busy?metadata_block_valid:(live&&fv));
 assign block_lba=metadata_busy?metadata_block_lba:flba;
 assign metadata_block_ready=rst_n&&metadata_busy&&block_ready;
 assign metadata_block_data_valid=rst_n&&metadata_busy&&block_data_valid;
 assign metadata_block_data=block_data;
 assign metadata_block_data_last=block_data_last;
 assign metadata_block_done_valid=rst_n&&metadata_busy&&block_done_valid;
 assign metadata_block_done_error=block_done_error;
 assign fr=live&&!metadata_busy&&block_ready;
 assign block_data_ready=rst_n&&(metadata_busy?metadata_block_data_ready:(aborting?outstanding:fdr));
 assign block_done_ready=rst_n&&(metadata_busy?metadata_block_done_ready:(aborting?outstanding:fcr));
 station_fat_file_cursor #(.MAX_FILE_BYTES(MAX_FILE_BYTES),.MAX_CHAIN_CLUSTERS(MAX_CHAIN_CLUSTERS),
  .MAX_DIR_CLUSTERS(MAX_DIR_CLUSTERS),.NATIVE_HISTORY(NATIVE_HISTORY)) cursor(
  .clk(clk),.rst_n(parser_rst),.open_valid(state==IDLE&&request&&!cancel&&metadata_quiet),.open_ready(open_ready),.short_name(short_name),
  .meta_valid(mv),.meta_ready(mready),.file_size(size),.data_valid(dv),.data_ready(dready),.data(byte_data),.data_last(byte_last),
  .done_valid(done),.done_ready(done_ready),.done_error(done_error),.error_code(ferr),
  .metadata_valid(cmdv),.metadata_ready(cmdr),.metadata_kind(metadata_kind),.metadata_lba(metadata_lba),
  .metadata_short_name(metadata_short_name),.metadata_cluster(metadata_cluster),.metadata_volume_start(metadata_volume_start),
  .metadata_partition_size(metadata_partition_size),.metadata_partitioned(metadata_partitioned),
  .metadata_result_valid(metadata_result_valid&&live),.metadata_result_ready(result_ready),.metadata_result_payload(metadata_result_payload),
  .block_valid(fv),.block_ready(fr),.block_lba(flba),
  .block_data_valid(block_data_valid&&live&&!metadata_busy),.block_data_ready(fdr),.block_data(block_data),.block_data_last(block_data_last),
  .block_done_valid(block_done_valid&&live&&!metadata_busy),.block_done_ready(fcr),.block_done_error(block_done_error));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=RESET;outstanding<=0;started<=0;saved_error<=0;end
  else begin
   if(fv&&fr)outstanding<=1;
   if(!metadata_busy&&block_done_valid&&block_done_ready)outstanding<=0;
   case(state)
    RESET:if(metadata_quiet)state<=IDLE;
    IDLE:if(request&&!cancel&&metadata_quiet&&open_ready)begin state<=ACTIVE;started<=0;saved_error<=0;end
    ACTIVE:begin
     if(start_valid&&start_ready)started<=1;
     if(done)saved_error<=ferr;
     if(done&&done_ready)state<=IDLE;
     if(cancel)state<=outstanding&&!(block_done_valid&&block_done_ready)?DRAIN:ABORT_RESET;
    end
    DRAIN:if(!metadata_busy&&block_done_valid&&block_done_ready)state<=ABORT_RESET;
    ABORT_RESET:begin state<=ABORT_CLOSE;saved_error<=4'hf;end
    ABORT_CLOSE:if(metadata_quiet&&(!started||source_done_ready||request))begin state<=IDLE;started<=0;end
    default:state<=RESET;
   endcase
  end
 end
endmodule
