// Parent SHA256 f80451449f606b15057056334d452c415343c80cd92178ea63de198a4612f3e9
`timescale 1ns/1ps
// Per-file FAT cursor/history. MBR/BPB/directory/FAT bytes are parsed by the
// shared metadata frontend. Only CRC-quarantined FILE bytes use this backend.
// One-sector backend, streaming data with EOF tail drain. No raw SD CRC claim.
// Local cancellation/reset ownership belongs in the file-context wrapper;
// its metadata adapter must remain globally alive until its lease drains.
module station_fat_file_cursor #(
 parameter integer MAX_FILE_BYTES=1048576,MAX_CHAIN_CLUSTERS=2048,MAX_DIR_CLUSTERS=128,
 parameter integer NATIVE_HISTORY=0
)(
 input wire clk,rst_n,open_valid,output wire open_ready,input wire [87:0] short_name,
 output wire meta_valid,input wire meta_ready,output reg [31:0] file_size,
 output wire data_valid,input wire data_ready,output wire [7:0] data,output wire data_last,
 output wire done_valid,input wire done_ready,output wire done_error,output reg [3:0] error_code,
 output wire metadata_valid,input wire metadata_ready,output wire [1:0] metadata_kind,
 output wire [31:0] metadata_lba,output wire [87:0] metadata_short_name,output wire [27:0] metadata_cluster,
 output wire [31:0] metadata_volume_start,metadata_partition_size,output wire metadata_partitioned,
 input wire metadata_result_valid,output wire metadata_result_ready,input wire [306:0] metadata_result_payload,
 output wire block_valid,input wire block_ready,output reg [31:0] block_lba,
 input wire block_data_valid,output wire block_data_ready,input wire [7:0] block_data,input wire block_data_last,
 input wire block_done_valid,output wire block_done_ready,input wire block_done_error
);
 localparam IDLE=0,METADATA_REQUEST=1,METADATA_WAIT=2,CHECK_CLUSTER=3,SEEN_FETCH=4,SEEN_COMPARE=5,
  SAVE_CLUSTER=6,CLUSTER_SECTOR=7,META=8,FILE_REQUEST=9,FILE_RECEIVE=10,NEXT_SECTOR=11,RESULT=12;
 localparam K_BOOT=0,K_DIR=1,K_FAT=2,K_FILE=3;
 function integer bits_for;input integer value;integer n;begin n=value-1;bits_for=0;while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam VW=bits_for(MAX_CHAIN_CLUSTERS);
 reg [3:0] state;reg [1:0] kind;reg [87:0] name_latched;
 reg [31:0] volume_start,partition_size,fat_start,data_start,max_cluster,first_cluster,remaining;
 reg partitioned,in_file,remaining_nonzero,remaining_last,framing_bad;
 reg [27:0] cluster,candidate;reg [7:0] spc,sector_in_cluster;reg [3:0] cluster_shift;
 reg [VW:0] seen_count;reg [VW-1:0] scan_index;wire [27:0] seen_value;reg [9:0] received;
 wire [1:0] mr_client,mr_kind;wire [7:0] mr_generation;wire [3:0] mr_error,mr_shift;
 wire mr_follow,mr_found,mr_dir_end;wire [31:0] mr_partition_start,mr_partition_size,mr_first_cluster,mr_size,mr_fat_entry,mr_fat_start,mr_data_start,mr_max_cluster;wire [27:0] mr_root_cluster;
 assign {mr_client,mr_kind,mr_generation,mr_error,mr_follow,mr_partition_start,mr_partition_size,mr_found,mr_dir_end,
  mr_first_cluster,mr_size,mr_fat_entry,mr_fat_start,mr_data_start,mr_max_cluster,mr_shift,mr_root_cluster}=metadata_result_payload;
 assign open_ready=rst_n&&state==IDLE;assign meta_valid=rst_n&&state==META;
 assign done_valid=rst_n&&state==RESULT;assign done_error=error_code!=0;
 assign metadata_valid=rst_n&&state==METADATA_REQUEST;assign metadata_kind=kind;assign metadata_lba=block_lba;
 assign metadata_short_name=name_latched;assign metadata_cluster=cluster;
 assign metadata_volume_start=volume_start;assign metadata_partition_size=partition_size;assign metadata_partitioned=partitioned;
 assign metadata_result_ready=rst_n&&state==METADATA_WAIT;
 assign block_valid=rst_n&&state==FILE_REQUEST;
 assign block_data_ready=rst_n&&state==FILE_RECEIVE&&(!remaining_nonzero||data_ready);
 assign block_done_ready=rst_n&&state==FILE_RECEIVE;
 assign data_valid=rst_n&&state==FILE_RECEIVE&&block_data_valid&&remaining_nonzero;
 assign data=block_data;assign data_last=data_valid&&remaining_last;
 wire take=block_data_valid&&block_data_ready;
 wire [10:0] count_after={1'b0,received}+(take?11'd1:11'd0);
 wire current_bad=take&&((received>=512)||(block_data_last!=(received==511)));
 // Only low32 address bits are consumed by CLUSTER_SECTOR. Preserve modulo
 // arithmetic for every4bit shift code; inference/resource benefit is measured.
 wire [31:0] cluster_delta={4'd0,candidate}-32'd2;
 wire [15:0] cluster_multiplier=16'd1<<cluster_shift;
 wire [47:0] cluster_product=cluster_delta*cluster_multiplier;
 wire [31:0] cluster_lba=data_start+cluster_product[31:0];
 assign seen_value = 28'd0;
 initial if(MAX_CHAIN_CLUSTERS<1||MAX_DIR_CLUSTERS<1)$error("Invalid FAT cursor history parameters");
 task fail;input [3:0] code;begin error_code<=code;state<=RESULT;end endtask
 task fetch;input [31:0] lba;input [1:0] what;begin
  block_lba<=lba;kind<=what;framing_bad<=0;state<=what==K_FILE?FILE_REQUEST:METADATA_REQUEST;
 end endtask
 task follow_fat;begin fetch(fat_start+{11'd0,cluster[27:7]},K_FAT);end endtask
 // Only FILE_RECEIVE consumes received/current_bad/count_after. Every entry
 // to that state passes through FILE_REQUEST, guaranteeing a zero baseline.
 // Clear outside receive independently of late metadata request/cancel logic;
 // retain saturating count, final-byte+completion samecycle and backpressure.
 // Value outside receive is unobserved; public transactions/cycles unchanged.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)received<=0;
  else if(state!=FILE_RECEIVE)received<=0;
  else if(take&&received<512)received<=received+1'b1;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;kind<=K_BOOT;name_latched<=0;file_size<=0;error_code<=0;block_lba<=0;
   volume_start<=0;partition_size<=0;fat_start<=0;data_start<=0;max_cluster<=0;first_cluster<=0;
   remaining<=0;partitioned<=0;in_file<=0;remaining_nonzero<=0;remaining_last<=0;
   cluster<=0;candidate<=0;spc<=0;sector_in_cluster<=0;cluster_shift<=0;seen_count<=0;scan_index<=0;framing_bad<=0;
  end else begin
   if(take)begin
    if(remaining_nonzero)begin remaining<=remaining-1'b1;remaining_nonzero<=!remaining_last;remaining_last<=remaining==2;end
    if(current_bad)framing_bad<=1;
   end
   case(state)
    IDLE:if(open_valid&&open_ready)begin
     name_latched<=short_name;file_size<=0;error_code<=0;volume_start<=0;partition_size<=0;
     partitioned<=0;in_file<=0;seen_count<=0;fetch(0,K_BOOT);
    end
    METADATA_REQUEST:if(metadata_ready)state<=METADATA_WAIT;
    METADATA_WAIT:if(metadata_result_valid&&metadata_result_ready)begin
     if(mr_kind!=kind)fail(4'he);
     else if(mr_error!=0)fail(mr_error);
     else case(kind)
      K_BOOT:if(mr_follow)begin
       volume_start<=mr_partition_start;partition_size<=mr_partition_size;partitioned<=1;fetch(mr_partition_start,K_BOOT);
      end else if(mr_shift>7)fail(4'he);
      else begin
       cluster_shift<=mr_shift;spc<=8'd1<<mr_shift;max_cluster<=mr_max_cluster;fat_start<=mr_fat_start;data_start<=mr_data_start;
       candidate<=mr_root_cluster;seen_count<=0;state<=CHECK_CLUSTER;
      end
      K_DIR:if(mr_found)begin
       file_size<=mr_size;first_cluster<=mr_first_cluster;
       if(mr_size>MAX_FILE_BYTES)fail(5);else state<=META;
      end else if(mr_dir_end)fail(4);
      else if(sector_in_cluster+1<spc)begin sector_in_cluster<=sector_in_cluster+1'b1;fetch(block_lba+1,K_DIR);end
      else follow_fat;
      K_FAT:if(mr_fat_entry[27:0]>=28'hffffff8)begin if(in_file)fail(6);else fail(4);end
       else begin candidate<=mr_fat_entry[27:0];state<=CHECK_CLUSTER;end
      default:fail(3);
     endcase
    end
    CHECK_CLUSTER:begin
     if(candidate<2||candidate>max_cluster||candidate>=28'hffffff0)fail(6);
     else if(seen_count>=MAX_CHAIN_CLUSTERS||(!in_file&&seen_count>=MAX_DIR_CLUSTERS))fail(8);
     else state<=SAVE_CLUSTER;
    end
    SEEN_FETCH:state<=SEEN_COMPARE;
    SEEN_COMPARE:if(seen_value==candidate)fail(7);
     else if({1'b0,scan_index}+1==seen_count)state<=SAVE_CLUSTER;
     else begin scan_index<=scan_index+1'b1;state<=SEEN_FETCH;end
    SAVE_CLUSTER:begin seen_count<=seen_count+1'b1;cluster<=candidate;sector_in_cluster<=0;state<=CLUSTER_SECTOR;end
    CLUSTER_SECTOR:fetch(cluster_lba[31:0],in_file?K_FILE:K_DIR);
    META:if(meta_ready)begin
     remaining<=file_size;remaining_nonzero<=file_size!=0;remaining_last<=file_size==1;in_file<=1;seen_count<=0;candidate<=first_cluster[27:0];
     if(file_size==0)state<=RESULT;else state<=CHECK_CLUSTER;
    end
    FILE_REQUEST:if(block_ready)state<=FILE_RECEIVE;
    FILE_RECEIVE:if(block_done_valid&&block_done_ready)begin
     if(block_done_error||framing_bad||current_bad||count_after!=512)fail(1);
     else if(!remaining_nonzero||(take&&remaining_last))state<=RESULT;
     else state<=NEXT_SECTOR;
    end
    NEXT_SECTOR:if(sector_in_cluster+1<spc)begin sector_in_cluster<=sector_in_cluster+1'b1;fetch(block_lba+1,K_FILE);end
     else follow_fat;
    RESULT:if(done_ready)state<=IDLE;
    default:fail(3);
   endcase
  end
 end
endmodule
