// Generic file backend remains strict by default.
`timescale 1ns/1ps
// Alternative source for station_three_files.v: never compile both.
// Three independent histories/positions/errors, one shared metadata parser.
// Existing CRC-quarantined cache and public file/SD interfaces are retained.
module station_three_files #(
 parameter integer VIDEO_MAX_BYTES=268435456,VIDEO_CHAIN=65536,
 parameter integer WAV_MAX_BYTES=16777216,WAV_CHAIN=8192,
 parameter integer PHOTO_MAX_BYTES=4194304,PHOTO_CHAIN=2048,DIR_CHAIN=512,BACKEND_QUARANTINED=0
)(
 input wire clk,rst_n,backend_failed,input wire [87:0] photo_short_name,
 input wire [2:0] file_request,file_cancel,
 output wire [2:0] start_valid,input wire [2:0] start_ready,output wire [95:0] file_size,
 output wire [2:0] byte_valid,input wire [2:0] byte_ready,output wire [23:0] byte_data,output wire [2:0] byte_last,
 output wire [2:0] source_done_valid,input wire [2:0] source_done_ready,output wire [2:0] source_done_error,
 output wire [2:0] quiescent,output wire [11:0] file_error,
 output wire read_valid,input wire read_ready,output wire [31:0] read_lba,
 input wire data_valid,output wire data_ready,input wire [7:0] data,input wire data_last,
 input wire done_valid,output wire done_ready,input wire done_error,
 output wire [31:0] sectors_ok,sectors_bad
);
 wire [2:0] bv,br,bdv,bdr,bl,bov,bor,be,busy;wire [95:0] lbas;wire [23:0] bytes;
 wire [2:0] cmdv,cmdr,part,cancel_meta,resultv,resultr,abort_done,fault,mquiet,mout,mlease;
 wire [5:0] kind;wire [95:0] mlba,volume,psize;wire [263:0] names;wire [83:0] cluster;wire [920:0] results;
 wire [2:0] mbv,mbr,mbdv,mbdr,mbl,mbov,mbor,mbe;wire [95:0] mblba;wire [23:0] mbdata;
 wire all_metadata_quiet,service_quiet,lease_valid;wire [1:0] lease_owner;
 genvar c;
 generate for(c=0;c<3;c=c+1)begin:files
  wire [87:0] name=c==0?"VIDEO000R56":c==1?"SONG000 WAV":photo_short_name;
  station_file_context_shared_metadata #(.MAX_FILE_BYTES(c==0?VIDEO_MAX_BYTES:c==1?WAV_MAX_BYTES:PHOTO_MAX_BYTES),
   .MAX_CHAIN_CLUSTERS(c==0?VIDEO_CHAIN:c==1?WAV_CHAIN:PHOTO_CHAIN),.MAX_DIR_CLUSTERS(DIR_CHAIN)) context_reader(
   .clk(clk),.rst_n(rst_n),.request(file_request[c]),.cancel(file_cancel[c]),.short_name(name),
   .start_valid(start_valid[c]),.start_ready(start_ready[c]),.file_size(file_size[c*32+:32]),
   .byte_valid(byte_valid[c]),.byte_ready(byte_ready[c]),.byte_data(byte_data[c*8+:8]),.byte_last(byte_last[c]),
   .source_done_valid(source_done_valid[c]),.source_done_ready(source_done_ready[c]),.source_done_error(source_done_error[c]),
   .quiescent(quiescent[c]),.error_code(file_error[c*4+:4]),
   .metadata_valid(cmdv[c]),.metadata_ready(cmdr[c]),.metadata_kind(kind[c*2+:2]),.metadata_lba(mlba[c*32+:32]),
   .metadata_short_name(names[c*88+:88]),.metadata_cluster(cluster[c*28+:28]),.metadata_volume_start(volume[c*32+:32]),
   .metadata_partition_size(psize[c*32+:32]),.metadata_partitioned(part[c]),
   .metadata_result_valid(resultv[c]),.metadata_result_ready(resultr[c]),.metadata_result_payload(results[c*307+:307]),
   .metadata_cancel(cancel_meta[c]),.metadata_quiet(mquiet[c]),
   .metadata_block_valid(mbv[c]),.metadata_block_ready(mbr[c]),.metadata_block_lba(mblba[c*32+:32]),
   .metadata_block_data_valid(mbdv[c]),.metadata_block_data_ready(mbdr[c]),.metadata_block_data(mbdata[c*8+:8]),.metadata_block_data_last(mbl[c]),
   .metadata_block_done_valid(mbov[c]),.metadata_block_done_ready(mbor[c]),.metadata_block_done_error(mbe[c]),
   .block_valid(bv[c]),.block_ready(br[c]),.block_lba(lbas[c*32+:32]),
   .block_data_valid(bdv[c]),.block_data_ready(bdr[c]),.block_data(bytes[c*8+:8]),.block_data_last(bl[c]),
   .block_done_valid(bov[c]),.block_done_ready(bor[c]),.block_done_error(be[c]));
 end endgenerate
 station_fat_metadata_frontend metadata(
  .clk(clk),.rst_n(rst_n),.c_command_valid(cmdv),.c_command_ready(cmdr),.c_kind(kind),.c_lba(mlba),.c_short_name(names),
  .c_cluster(cluster),.c_volume_start(volume),.c_partition_size(psize),.c_partitioned(part),.c_cancel(cancel_meta),
  .c_result_valid(resultv),.c_result_ready(resultr),.c_result_payload(results),.c_abort_done(abort_done),.c_protocol_fault(fault),
  .c_quiet(mquiet),.c_sector_outstanding(mout),.c_lease_active(mlease),.quiet(all_metadata_quiet),.service_quiet(service_quiet),
  .service_lease_valid(lease_valid),.service_lease_owner(lease_owner),
  .c_block_valid(mbv),.c_block_ready(mbr),.c_block_lba(mblba),.c_block_data_valid(mbdv),.c_block_data_ready(mbdr),
  .c_block_data(mbdata),.c_block_last(mbl),.c_block_done_valid(mbov),.c_block_done_ready(mbor),.c_block_done_error(mbe));
 station_sector_cache #(.CLIENTS(3),.NATIVE_STREAM(BACKEND_QUARANTINED)) cache(.clk(clk),.rst_n(rst_n),.backend_failed(backend_failed),
  .c_request(bv),.c_ready(br),.c_lba(lbas),.c_data_valid(bdv),.c_data_ready(bdr),.c_data(bytes),.c_last(bl),
  .c_done_valid(bov),.c_done_ready(bor),.c_error(be),.c_busy(busy),
  .read_valid(read_valid),.read_ready(read_ready),.read_lba(read_lba),.data_valid(data_valid),.data_ready(data_ready),.data(data),.data_last(data_last),
  .done_valid(done_valid),.done_ready(done_ready),.done_error(done_error),.sectors_ok(sectors_ok),.sectors_bad(sectors_bad));
endmodule
