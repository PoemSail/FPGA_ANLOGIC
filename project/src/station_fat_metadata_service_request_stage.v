// Unselected request-stage derivative; parent SHA256 53a38b4ac63102dddb8ddd6962f101b67cb7ea92983b01767962233639b281ad
`timescale 1ns/1ps
// Three independent metadata clients, one complete-sector parser lease.
// Round-robin advances only when a result is accepted. Non-owner byte/done
// channels never handshake. Pending cancellation masks a request; accepted
// cancellation drains the owner through done and its tagged result. Clients
// MUST accept/discard their result after cancellation (generation filtering
// belongs in the context adapter). Global reset resets parser and arbiter.
module station_fat_metadata_service(
 input wire clk,rst_n,input wire [2:0] c_request_valid,output wire [2:0] c_request_ready,
 input wire [5:0] c_kind,input wire [23:0] c_generation,input wire [263:0] c_short_name,
 input wire [83:0] c_cluster,input wire [95:0] c_volume_start,c_partition_size,input wire [2:0] c_partitioned,c_cancel,
 input wire [2:0] c_byte_valid,output wire [2:0] c_byte_ready,input wire [23:0] c_byte_data,input wire [2:0] c_byte_last,
 input wire [2:0] c_done_valid,output wire [2:0] c_done_ready,input wire [2:0] c_done_error,
 output wire [2:0] c_result_valid,input wire [2:0] c_result_ready,
 output wire quiet,output wire lease_valid,output wire [1:0] lease_owner,
 output wire [1:0] result_client,result_kind,output wire [7:0] result_generation,
 output wire [3:0] result_error,output wire result_follow_partition,
 output wire [31:0] result_partition_start,result_partition_size,
 output wire result_found,result_directory_end,
 output wire [31:0] result_first_cluster,result_file_size,result_fat_entry,
 output wire [31:0] result_fat_start,result_data_start,result_max_cluster,
 output wire [3:0] result_cluster_shift,output wire [27:0] result_root_cluster
);
 reg active,pending,cancel_seen;reg [1:0] owner,next_client,selected;reg have_request;
 // One191-bit command register; payload may change immediately after client
 // acceptance. Parser admits it on the following edge, never combinationally
 // from another file's state/cancel/fault tree. One lease remains outstanding.
 reg [1:0] held_kind;reg [7:0] held_generation;reg [87:0] held_name;
 reg [27:0] held_cluster;reg [31:0] held_volume,held_size;reg held_partitioned;
 wire [2:0] eligible=c_request_valid&~c_cancel;
 always @*begin
  selected=0;have_request=|eligible;
  case(next_client)
   0:if(eligible[0])selected=0;else if(eligible[1])selected=1;else selected=2;
   1:if(eligible[1])selected=1;else if(eligible[2])selected=2;else selected=0;
   default:if(eligible[2])selected=2;else if(eligible[0])selected=0;else selected=1;
  endcase
 end
 wire engine_request_ready,engine_byte_ready,engine_done_ready,engine_result_valid,engine_quiet;
 wire engine_request_valid=rst_n&&active&&pending;
 wire engine_result_ready=active&&c_result_ready[owner];
 wire request_take=rst_n&&!active&&have_request&&engine_quiet;
 wire result_take=active&&engine_result_valid&&engine_result_ready;
 assign c_request_ready=rst_n&&!active&&have_request&&engine_quiet?(3'b001<<selected):3'b000;
 assign c_byte_ready=rst_n&&active&&engine_byte_ready?(3'b001<<owner):3'b000;
 assign c_done_ready=rst_n&&active&&engine_done_ready?(3'b001<<owner):3'b000;
 assign c_result_valid=rst_n&&active&&engine_result_valid?(3'b001<<owner):3'b000;
 assign quiet=rst_n&&!active&&engine_quiet;
 assign lease_valid=rst_n&&active;assign lease_owner=owner;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   active<=0;owner<=0;next_client<=0;pending<=0;cancel_seen<=0;
   held_kind<=0;held_generation<=0;held_name<=0;held_cluster<=0;
   held_volume<=0;held_size<=0;held_partitioned<=0;
  end
  else begin
   if(request_take)begin
    active<=1;owner<=selected;pending<=1;cancel_seen<=0;
    held_kind<=c_kind[selected*2+:2];held_generation<=c_generation[selected*8+:8];
    held_name<=c_short_name[selected*88+:88];held_cluster<=c_cluster[selected*28+:28];
    held_volume<=c_volume_start[selected*32+:32];held_size<=c_partition_size[selected*32+:32];
    held_partitioned<=c_partitioned[selected];
   end
   if(engine_request_valid&&engine_request_ready)pending<=0;
   // Catch cancellation even during the one-edge admission gap; feeding it
   // to an idle parser would mask request_ready and deadlock the lease.
   if(active&&c_cancel[owner])cancel_seen<=1;
   if(result_take)begin active<=0;pending<=0;cancel_seen<=0;next_client<=owner==2?0:owner+1'b1;end
  end
 end
 station_fat_metadata_engine engine(
  .clk(clk),.rst_n(rst_n),.request_valid(engine_request_valid),.request_ready(engine_request_ready),
  .request_client(owner),.request_kind(held_kind),.request_generation(held_generation),
  .request_short_name(held_name),.request_cluster(held_cluster),
  .request_volume_start(held_volume),.request_partition_size(held_size),
  .request_partitioned(held_partitioned),.cancel(active&&!pending&&(cancel_seen||c_cancel[owner])),
  .byte_valid(active&&c_byte_valid[owner]),.byte_ready(engine_byte_ready),.byte_data(c_byte_data[owner*8+:8]),.byte_last(c_byte_last[owner]),
  .done_valid(active&&c_done_valid[owner]),.done_ready(engine_done_ready),.done_error(c_done_error[owner]),
  .result_valid(engine_result_valid),.result_ready(engine_result_ready),.quiet(engine_quiet),
  .result_client(result_client),.result_kind(result_kind),.result_generation(result_generation),.result_error(result_error),
  .result_follow_partition(result_follow_partition),.result_partition_start(result_partition_start),.result_partition_size(result_partition_size),
  .result_found(result_found),.result_directory_end(result_directory_end),.result_first_cluster(result_first_cluster),.result_file_size(result_file_size),
  .result_fat_entry(result_fat_entry),.result_fat_start(result_fat_start),.result_data_start(result_data_start),.result_max_cluster(result_max_cluster),
  .result_cluster_shift(result_cluster_shift),.result_root_cluster(result_root_cluster));
endmodule
