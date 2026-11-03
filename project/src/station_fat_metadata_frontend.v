`timescale 1ns/1ps
// Three per-file cancellation/generation adapters around ONE metadata service.
// Backend ports attach to each client's existing sector-cache channel. File
// content sectors bypass this frontend in the future file-context integration.
// All reset inputs here are global. Per-file cancellation is c_cancel only.
module station_fat_metadata_frontend(
 input wire clk,rst_n,input wire [2:0] c_command_valid,output wire [2:0] c_command_ready,
 input wire [5:0] c_kind,input wire [95:0] c_lba,input wire [263:0] c_short_name,
 input wire [83:0] c_cluster,input wire [95:0] c_volume_start,c_partition_size,input wire [2:0] c_partitioned,c_cancel,
 output wire [2:0] c_result_valid,input wire [2:0] c_result_ready,output wire [920:0] c_result_payload,
 output wire [2:0] c_abort_done,c_protocol_fault,c_quiet,c_sector_outstanding,c_lease_active,
 output wire quiet,service_quiet,service_lease_valid,output wire [1:0] service_lease_owner,
 output wire [2:0] c_block_valid,input wire [2:0] c_block_ready,output wire [95:0] c_block_lba,
 input wire [2:0] c_block_data_valid,output wire [2:0] c_block_data_ready,input wire [23:0] c_block_data,input wire [2:0] c_block_last,
 input wire [2:0] c_block_done_valid,output wire [2:0] c_block_done_ready,input wire [2:0] c_block_done_error
);
 wire [2:0] request_valid,request_ready,partitioned,cancel,byte_valid,byte_ready,byte_last,done_valid,done_ready,done_error,result_valid,result_ready;
 wire [5:0] kind;wire [23:0] generation,byte_data;wire [263:0] short_name;wire [83:0] cluster;wire [95:0] volume_start,partition_size;
 wire [1:0] result_client,result_kind;wire [7:0] result_generation;wire [3:0] result_error,result_cluster_shift;
 wire result_follow_partition,result_found,result_directory_end;
 wire [31:0] result_partition_start,result_partition_size,result_first_cluster,result_file_size,result_fat_entry,result_fat_start,result_data_start,result_max_cluster;
 wire [27:0] result_root_cluster;
 wire [306:0] payload={result_client,result_kind,result_generation,result_error,result_follow_partition,
  result_partition_start,result_partition_size,result_found,result_directory_end,result_first_cluster,result_file_size,result_fat_entry,
  result_fat_start,result_data_start,result_max_cluster,result_cluster_shift,result_root_cluster};
 assign quiet=rst_n&&(&c_quiet)&&service_quiet;
 genvar c;
 generate for(c=0;c<3;c=c+1)begin:clients
  station_fat_metadata_adapter #(.CLIENT_ID(c)) adapter(
   .clk(clk),.rst_n(rst_n),.cancel(c_cancel[c]),.command_valid(c_command_valid[c]),.command_ready(c_command_ready[c]),
   .command_kind(c_kind[c*2+:2]),.command_lba(c_lba[c*32+:32]),.command_short_name(c_short_name[c*88+:88]),.command_cluster(c_cluster[c*28+:28]),
   .command_volume_start(c_volume_start[c*32+:32]),.command_partition_size(c_partition_size[c*32+:32]),.command_partitioned(c_partitioned[c]),
   .result_valid(c_result_valid[c]),.result_ready(c_result_ready[c]),.result_payload(c_result_payload[c*307+:307]),
   .abort_done(c_abort_done[c]),.protocol_fault(c_protocol_fault[c]),.quiet(c_quiet[c]),.sector_outstanding(c_sector_outstanding[c]),.lease_active(c_lease_active[c]),
   .service_request_valid(request_valid[c]),.service_request_ready(request_ready[c]),.service_kind(kind[c*2+:2]),.service_generation(generation[c*8+:8]),
   .service_short_name(short_name[c*88+:88]),.service_cluster(cluster[c*28+:28]),.service_volume_start(volume_start[c*32+:32]),.service_partition_size(partition_size[c*32+:32]),
   .service_partitioned(partitioned[c]),.service_cancel(cancel[c]),.service_byte_valid(byte_valid[c]),.service_byte_ready(byte_ready[c]),.service_byte_data(byte_data[c*8+:8]),.service_byte_last(byte_last[c]),
   .service_done_valid(done_valid[c]),.service_done_ready(done_ready[c]),.service_done_error(done_error[c]),
   .service_result_valid(result_valid[c]),.service_result_ready(result_ready[c]),.service_result_payload(payload),
   .block_valid(c_block_valid[c]),.block_ready(c_block_ready[c]),.block_lba(c_block_lba[c*32+:32]),
   .block_data_valid(c_block_data_valid[c]),.block_data_ready(c_block_data_ready[c]),.block_data(c_block_data[c*8+:8]),.block_data_last(c_block_last[c]),
   .block_done_valid(c_block_done_valid[c]),.block_done_ready(c_block_done_ready[c]),.block_done_error(c_block_done_error[c]));
 end endgenerate
 station_fat_metadata_service service(
  .clk(clk),.rst_n(rst_n),.c_request_valid(request_valid),.c_request_ready(request_ready),.c_kind(kind),.c_generation(generation),.c_short_name(short_name),
  .c_cluster(cluster),.c_volume_start(volume_start),.c_partition_size(partition_size),.c_partitioned(partitioned),.c_cancel(cancel),
  .c_byte_valid(byte_valid),.c_byte_ready(byte_ready),.c_byte_data(byte_data),.c_byte_last(byte_last),.c_done_valid(done_valid),.c_done_ready(done_ready),.c_done_error(done_error),
  .c_result_valid(result_valid),.c_result_ready(result_ready),.quiet(service_quiet),.lease_valid(service_lease_valid),.lease_owner(service_lease_owner),
  .result_client(result_client),.result_kind(result_kind),.result_generation(result_generation),.result_error(result_error),.result_follow_partition(result_follow_partition),
  .result_partition_start(result_partition_start),.result_partition_size(result_partition_size),.result_found(result_found),.result_directory_end(result_directory_end),
  .result_first_cluster(result_first_cluster),.result_file_size(result_file_size),.result_fat_entry(result_fat_entry),.result_fat_start(result_fat_start),
  .result_data_start(result_data_start),.result_max_cluster(result_max_cluster),.result_cluster_shift(result_cluster_shift),.result_root_cluster(result_root_cluster));
endmodule
