`timescale 1ns/1ps
// Isolated exact-cycle payload/status separation; production source preserved.
module station_fat_metadata_engine(
 input wire  clk,
 input wire  rst_n,
 input wire  request_valid,
 output wire  request_ready,
 input wire [1:0] request_client,
 input wire [1:0] request_kind,
 input wire [7:0] request_generation,
 input wire [87:0] request_short_name,
 input wire [27:0] request_cluster,
 input wire [31:0] request_volume_start,
 input wire [31:0] request_partition_size,
 input wire  request_partitioned,
 input wire  cancel,
 input wire  byte_valid,
 output wire  byte_ready,
 input wire [7:0] byte_data,
 input wire  byte_last,
 input wire  done_valid,
 output wire  done_ready,
 input wire  done_error,
 output wire  result_valid,
 input wire  result_ready,
 output wire  quiet,
 output reg [1:0] result_client,
 output reg [1:0] result_kind,
 output reg [7:0] result_generation,
 output reg [3:0] result_error,
 output wire  result_follow_partition,
 output wire [31:0] result_partition_start,
 output wire [31:0] result_partition_size,
 output wire  result_found,
 output wire  result_directory_end,
 output wire [31:0] result_first_cluster,
 output wire [31:0] result_file_size,
 output wire [31:0] result_fat_entry,
 output wire [31:0] result_fat_start,
 output wire [31:0] result_data_start,
 output wire [31:0] result_max_cluster,
 output wire [3:0] result_cluster_shift,
 output wire [27:0] result_root_cluster
);
// Raw payload is allowed to compute on a cancelled CHECK. The status
// register preserves cancellation priority. Every error exposes zero payload,
// matching reset/IDLE-cleared public outputs in the original reachable protocol.
 reg  raw_result_follow_partition;
 reg [31:0] raw_result_partition_start;
 reg [31:0] raw_result_partition_size;
 reg  raw_result_found;
 reg  raw_result_directory_end;
 reg [31:0] raw_result_first_cluster;
 reg [31:0] raw_result_file_size;
 reg [31:0] raw_result_fat_entry;
 reg [31:0] raw_result_fat_start;
 reg [31:0] raw_result_data_start;
 reg [31:0] raw_result_max_cluster;
 reg [3:0] raw_result_cluster_shift;
 reg [27:0] raw_result_root_cluster;
 assign result_follow_partition=(result_error==0)?raw_result_follow_partition:0;
 assign result_partition_start=(result_error==0)?raw_result_partition_start:0;
 assign result_partition_size=(result_error==0)?raw_result_partition_size:0;
 assign result_found=(result_error==0)?raw_result_found:0;
 assign result_directory_end=(result_error==0)?raw_result_directory_end:0;
 assign result_first_cluster=(result_error==0)?raw_result_first_cluster:0;
 assign result_file_size=(result_error==0)?raw_result_file_size:0;
 assign result_fat_entry=(result_error==0)?raw_result_fat_entry:0;
 assign result_fat_start=(result_error==0)?raw_result_fat_start:0;
 assign result_data_start=(result_error==0)?raw_result_data_start:0;
 assign result_max_cluster=(result_error==0)?raw_result_max_cluster:0;
 assign result_cluster_shift=(result_error==0)?raw_result_cluster_shift:0;
 assign result_root_cluster=(result_error==0)?raw_result_root_cluster:0;

 localparam IDLE=0,RECEIVE=1,SETTLE=2,CHECK=3,RESULT=4,GEOM0=5,GEOM1=6,GEOM2=7;
 reg [2:0] state;reg [9:0] received;reg framing_bad,cancelled,source_bad;
 reg [87:0] short_name;reg [27:0] target_cluster;
 reg [31:0] volume_start,partition_size;reg partitioned;
 reg [255:0] window;wire [255:0] entry={window[247:0],byte_data};
 wire [127:0] part={window[119:0],byte_data};
 reg part_found,found,dir_end;reg [31:0] part_start,part_size,first_cluster,file_size,fat_entry;
 reg [15:0] bps,reserved,flags,signature;reg zero_bad;
 reg [7:0] spc,fats,jump;reg [31:0] total32,fat32,root_cluster;reg [3:0] shift_value;
 always @*case(spc)
  1:shift_value=0;2:shift_value=1;4:shift_value=2;8:shift_value=3;
  16:shift_value=4;32:shift_value=5;64:shift_value=6;128:shift_value=7;default:shift_value=0;
 endcase
 wire spc_ok=spc==8'd1||spc==8'd2||spc==8'd4||spc==8'd8||spc==8'd16||spc==8'd32||spc==8'd64||spc==8'd128;
 reg [63:0] checked_overhead,checked_clusters;reg checked_geometry_bad;
 wire [63:0] fat_span=fats==2?({32'd0,fat32}<<1):{32'd0,fat32};
 wire [63:0] overhead={48'd0,reserved}+fat_span;
 wire [63:0] clusters=({32'd0,total32}-checked_overhead)>>shift_value;
 wire [63:0] volume_end={32'd0,volume_start}+{32'd0,total32};
 wire [63:0] partition_end={32'd0,part_start}+{32'd0,part_size};
 wire geometry_bad=bps!=512||!spc_ok||reserved==0||(fats!=1&&fats!=2)||zero_bad||fat32==0||
  (jump!=8'heb&&jump!=8'he9)||(flags[7]&&flags[3:0]>=fats)||total32<=checked_overhead||
  checked_clusters<65525||checked_clusters>64'h0fffffee||({32'd0,fat32}<<7)<checked_clusters+64'd2||
  volume_end>64'h100000000||(partitioned&&total32>partition_size);
 wire take=byte_valid&&byte_ready;
 wire [10:0] count_after={1'b0,received}+(take?11'd1:11'd0);
 wire current_bad=take&&((received>=512)||(byte_last!=(received==511)));
 assign request_ready=rst_n&&state==IDLE&&!cancel;
 assign byte_ready=rst_n&&state==RECEIVE;
 assign done_ready=rst_n&&state==RECEIVE;
 assign result_valid=rst_n&&state==RESULT;
 assign quiet=rst_n&&state==IDLE;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   checked_overhead<=0;checked_clusters<=0;checked_geometry_bad<=0;
   state<=IDLE;received<=0;framing_bad<=0;cancelled<=0;source_bad<=0;
   short_name<=0;target_cluster<=0;volume_start<=0;partition_size<=0;partitioned<=0;
   window<=0;part_found<=0;found<=0;dir_end<=0;part_start<=0;part_size<=0;
   first_cluster<=0;file_size<=0;fat_entry<=0;bps<=0;reserved<=0;flags<=0;signature<=0;zero_bad<=0;
   spc<=0;fats<=0;jump<=0;total32<=0;fat32<=0;root_cluster<=0;
   result_client<=0;result_kind<=0;result_generation<=0;result_error<=0;raw_result_follow_partition<=0;
   raw_result_partition_start<=0;raw_result_partition_size<=0;raw_result_found<=0;raw_result_directory_end<=0;
   raw_result_first_cluster<=0;raw_result_file_size<=0;raw_result_fat_entry<=0;
   raw_result_fat_start<=0;raw_result_data_start<=0;raw_result_max_cluster<=0;raw_result_cluster_shift<=0;raw_result_root_cluster<=0;
  end else begin
   if(cancel&&(state==RECEIVE||state==SETTLE||state==GEOM0||state==GEOM1||state==GEOM2||state==CHECK))cancelled<=1;
   case(state)
    IDLE:if(request_valid&&request_ready)begin
     result_client<=request_client;result_kind<=request_kind;result_generation<=request_generation;
     short_name<=request_short_name;target_cluster<=request_cluster;
     volume_start<=request_volume_start;partition_size<=request_partition_size;partitioned<=request_partitioned;
     received<=0;framing_bad<=0;cancelled<=0;source_bad<=0;window<=0;
     part_found<=0;found<=0;dir_end<=0;part_start<=0;part_size<=0;first_cluster<=0;file_size<=0;fat_entry<=0;
     bps<=0;reserved<=0;flags<=0;signature<=0;zero_bad<=0;spc<=0;fats<=0;jump<=0;total32<=0;fat32<=0;root_cluster<=0;
     result_error<=0;raw_result_follow_partition<=0;raw_result_partition_start<=0;raw_result_partition_size<=0;
     raw_result_found<=0;raw_result_directory_end<=0;raw_result_first_cluster<=0;raw_result_file_size<=0;raw_result_fat_entry<=0;
     raw_result_fat_start<=0;raw_result_data_start<=0;raw_result_max_cluster<=0;raw_result_cluster_shift<=0;raw_result_root_cluster<=0;
     if(request_client==3||request_kind==3)begin result_error<=3;state<=RESULT;end
     else state<=RECEIVE;
    end
    RECEIVE:begin
     if(take)begin
      if(received<512)received<=received+1'b1;
      if(current_bad)framing_bad<=1;
      if(result_kind==0)begin
       case(received)
        0:jump<=byte_data;
        11:bps[7:0]<=byte_data;12:bps[15:8]<=byte_data;13:spc<=byte_data;
        14:reserved[7:0]<=byte_data;15:reserved[15:8]<=byte_data;16:fats<=byte_data;
        17,18,19,20,22,23,42,43:if(byte_data!=0)zero_bad<=1;
        32:total32[7:0]<=byte_data;33:total32[15:8]<=byte_data;34:total32[23:16]<=byte_data;35:total32[31:24]<=byte_data;
        36:fat32[7:0]<=byte_data;37:fat32[15:8]<=byte_data;38:fat32[23:16]<=byte_data;39:fat32[31:24]<=byte_data;
        40:flags[7:0]<=byte_data;41:flags[15:8]<=byte_data;
        44:root_cluster[7:0]<=byte_data;45:root_cluster[15:8]<=byte_data;46:root_cluster[23:16]<=byte_data;47:root_cluster[31:24]<=byte_data;
        510:signature[7:0]<=byte_data;511:signature[15:8]<=byte_data;default:;
       endcase
       if(received>=446&&received<510)begin
        window<=entry;
        if((received-446)%16==15&&!part_found&&(part[127:120]==0||part[127:120]==8'h80)&&
           (part[95:88]==8'h0b||part[95:88]==8'h0c))begin
         part_found<=1;part_start<={part[39:32],part[47:40],part[55:48],part[63:56]};
         part_size<={part[7:0],part[15:8],part[23:16],part[31:24]};
        end
       end
      end else if(result_kind==1)begin
       window<=entry;
       if(received[4:0]==31&&!found&&!dir_end)begin
        if(entry[255:248]==0)dir_end<=1;
        else if(entry[255:248]!=8'he5&&entry[167:160]!=8'h0f&&(entry[167:160]&8'h18)==0&&entry[255:168]==short_name)begin
         found<=1;first_cluster<={4'd0,entry[83:80],entry[95:88],entry[39:32],entry[47:40]};
         file_size<={entry[7:0],entry[15:8],entry[23:16],entry[31:24]};
        end
       end
      end else if(result_kind==2&&received[8:2]==target_cluster[6:0])begin
       case(received[1:0])0:fat_entry[7:0]<=byte_data;1:fat_entry[15:8]<=byte_data;
        2:fat_entry[23:16]<=byte_data;3:fat_entry[31:24]<=byte_data;endcase
      end
     end
     if(done_valid&&done_ready)begin
      source_bad<=done_error||framing_bad||current_bad||count_after!=512;state<=SETTLE;
     end
    end
    // Fields are final after sector completion. Keep the single tagged lease
    // while splitting overhead, cluster division and range checks over clocks.
    // No result or quiet is advertised until CHECK/RESULT completes; cancel in
    // every added state retains the original error-F priority.
    SETTLE:begin checked_overhead<=overhead;state<=GEOM0;end
    GEOM0:begin checked_clusters<=clusters;state<=GEOM1;end
    GEOM1:begin checked_geometry_bad<=geometry_bad;state<=GEOM2;end
    GEOM2:state<=CHECK;
    CHECK:begin
     state<=RESULT;
     if(source_bad)result_error<=1;
     else case(result_kind)
      0:begin
       if(signature!=16'haa55)result_error<=2;
       else if(bps!=512&&!partitioned)begin
        if(!part_found||part_start==0||part_size==0||partition_end>64'h100000000)result_error<=2;
        else begin raw_result_follow_partition<=1;raw_result_partition_start<=part_start;raw_result_partition_size<=part_size;end
       end else if(checked_geometry_bad)result_error<=3;
       else begin
        raw_result_fat_start<=volume_start+reserved+((flags[7]&&flags[3:0]==1)?fat32:0);
        raw_result_data_start<=volume_start+checked_overhead[31:0];raw_result_max_cluster<=checked_clusters[31:0]+1'b1;
        raw_result_cluster_shift<=shift_value;raw_result_root_cluster<=root_cluster[27:0];
       end
      end
      1:begin raw_result_found<=found;raw_result_directory_end<=dir_end;raw_result_first_cluster<=first_cluster;raw_result_file_size<=file_size;end
      2:raw_result_fat_entry<=fat_entry;
      default:result_error<=3;
     endcase
     // Only the registered status depends on the immediate cancellation tree.
     if(cancelled||cancel)result_error<=4'hf;
    end
    RESULT:if(result_ready)state<=IDLE;
    default:begin state<=RESULT;result_error<=3;end
   endcase
  end
 end
endmodule
