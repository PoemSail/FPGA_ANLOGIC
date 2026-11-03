`timescale 1ns/1ps
// Shared production subsystem used by full system and SD/SDRAM pin-model tests.
module station_picture_storage #(
 parameter integer SD_POWER_WAIT=500000,SD_INIT_TIMEOUT=100000000,SD_TOKEN_TIMEOUT=5000000,SD_INIT_HALF=64,SD_DATA_HALF=2,
 parameter integer VIDEO_MAX_BYTES=268435456,VIDEO_CHAIN=65536,WAV_MAX_BYTES=16777216,WAV_CHAIN=8192,
 parameter integer PHOTO_MAX_BYTES=4194304,PHOTO_CHAIN=2048,DIR_CHAIN=512,MEMORY_POWER=10000,MEMORY_REFRESH=150
)(
 input wire clk,rst_n,arst_n,forwarded_clk,
 input wire [1:0] file_request,file_cancel,output wire [1:0] start_valid,input wire [1:0] start_ready,output wire [63:0] file_size,
 output wire [1:0] byte_valid,input wire [1:0] byte_ready,output wire [15:0] byte_data,output wire [1:0] byte_last,
 output wire [1:0] source_done_valid,input wire [1:0] source_done_ready,output wire [1:0] source_done_error,
 input wire core_mem_wr_valid,output wire core_mem_wr_ready,input wire [20:0] core_mem_wr_address,input wire [31:0] core_mem_wr_data,
 output wire core_mem_wr_rsp_valid,input wire core_mem_wr_rsp_ready,output wire core_mem_wr_rsp_error,
 input wire core_mem_rd_valid,output wire core_mem_rd_ready,input wire [20:0] core_mem_rd_address,
 output wire core_mem_rd_data_valid,output wire [31:0] core_mem_rd_data,output wire core_mem_rd_last,
 input wire photo_request_valid,output wire photo_request_ready,input wire [1:0] photo_index,input wire photo_cancel,
 output wire photo_descriptor_valid,input wire photo_descriptor_ready,output wire photo_descriptor_error,
 output wire [7:0] photo_error,output wire [1:0] photo_error_stage,output wire [20:0] photo_base,output wire photo_slot,output wire [15:0] photo_generation,
 input wire photo_release_valid,photo_release_slot,input wire [15:0] photo_release_generation,input wire photo_clear_fault,
 output wire [1:0] photo_busy,photo_published,output wire photo_pool_fault,share_fault,
 input wire sd_retry_valid,output wire sd_retry_ready,sd_initialized,output wire [3:0] sd_error,
 output wire [2:0] files_quiescent,output wire [11:0] files_error,output wire [31:0] sectors_ok,sectors_bad,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat,
 output wire memory_initialized,memory_backend_quiet,memory_fault,memory_quiet,
 output wire [31:0] memory_write_acks,memory_read_bursts,memory_refreshes,
 output wire sdram_clk,sdram_ras_n,sdram_cas_n,sdram_we_n,output wire [10:0] sdram_addr,output wire [1:0] sdram_ba,
 output wire [3:0] sdram_dqm,inout wire [31:0] sdram_dq
);
 wire photo_quiet,share_quiet;
 wire pwr,pwready,pack,packready,perr,prd,prready,pdv,plast;

 wire [20:0] pwa,pra;wire [31:0] pwd,pdata;

 wire bwr,bwready,back,backready,berr,brd,brready,bdv,blast;

 wire [20:0] bwa,bra;wire [31:0] bwd,bdata;

 wire photo_file_request,photo_file_cancel,photo_start_valid,photo_start_ready;

 wire photo_byte_valid,photo_byte_ready,photo_byte_last,photo_source_done_valid,photo_source_done_ready,photo_source_done_error;

 wire [31:0] photo_file_size;wire [7:0] photo_byte_data;wire [87:0] photo_short_name;

 assign memory_quiet=photo_quiet&&share_quiet&&memory_backend_quiet;


 wire video_file_request;
 assign video_file_request=file_request[0];
 wire wav_file_request;
 assign wav_file_request=file_request[1];
 wire video_file_cancel;
 assign video_file_cancel=file_cancel[0];
 wire wav_file_cancel;
 assign wav_file_cancel=file_cancel[1];
 wire video_start_valid;
 assign start_valid[0]=video_start_valid;
 wire wav_start_valid;
 assign start_valid[1]=wav_start_valid;
 wire video_start_ready;
 assign video_start_ready=start_ready[0];
 wire wav_start_ready;
 assign wav_start_ready=start_ready[1];
 wire [31:0] video_file_size;
 assign file_size[0+:32]=video_file_size;
 wire [31:0] wav_file_size;
 assign file_size[32+:32]=wav_file_size;
 wire video_byte_valid;
 assign byte_valid[0]=video_byte_valid;
 wire wav_byte_valid;
 assign byte_valid[1]=wav_byte_valid;
 wire video_byte_ready;
 assign video_byte_ready=byte_ready[0];
 wire wav_byte_ready;
 assign wav_byte_ready=byte_ready[1];
 wire [7:0] video_byte_data;
 assign byte_data[0+:8]=video_byte_data;
 wire [7:0] wav_byte_data;
 assign byte_data[8+:8]=wav_byte_data;
 wire video_byte_last;
 assign byte_last[0]=video_byte_last;
 wire wav_byte_last;
 assign byte_last[1]=wav_byte_last;
 wire video_source_done_valid;
 assign source_done_valid[0]=video_source_done_valid;
 wire wav_source_done_valid;
 assign source_done_valid[1]=wav_source_done_valid;
 wire video_source_done_ready;
 assign video_source_done_ready=source_done_ready[0];
 wire wav_source_done_ready;
 assign wav_source_done_ready=source_done_ready[1];
 wire video_source_done_error;
 assign source_done_error[0]=video_source_done_error;
 wire wav_source_done_error;
 assign source_done_error[1]=wav_source_done_error; station_sd_three_files #(.POWER_WAIT_CYCLES(SD_POWER_WAIT),.INIT_TIMEOUT_CYCLES(SD_INIT_TIMEOUT),.TOKEN_TIMEOUT_CYCLES(SD_TOKEN_TIMEOUT),

  .INIT_HALF_PERIOD(SD_INIT_HALF),.DATA_HALF_PERIOD(SD_DATA_HALF),.VIDEO_MAX_BYTES(VIDEO_MAX_BYTES),.VIDEO_CHAIN(VIDEO_CHAIN),

  .WAV_MAX_BYTES(WAV_MAX_BYTES),.WAV_CHAIN(WAV_CHAIN),.PHOTO_MAX_BYTES(PHOTO_MAX_BYTES),.PHOTO_CHAIN(PHOTO_CHAIN),.DIR_CHAIN(DIR_CHAIN)) storage(

  .clk(clk),.rst_n(rst_n),.retry_valid(sd_retry_valid),.retry_ready(sd_retry_ready),.initialized(sd_initialized),.sd_error(sd_error),.photo_short_name(photo_short_name),

  .file_request({photo_file_request,wav_file_request,video_file_request}),.file_cancel({photo_file_cancel,wav_file_cancel,video_file_cancel}),

  .start_valid({photo_start_valid,wav_start_valid,video_start_valid}),.start_ready({photo_start_ready,wav_start_ready,video_start_ready}),.file_size({photo_file_size,wav_file_size,video_file_size}),

  .byte_valid({photo_byte_valid,wav_byte_valid,video_byte_valid}),.byte_ready({photo_byte_ready,wav_byte_ready,video_byte_ready}),.byte_data({photo_byte_data,wav_byte_data,video_byte_data}),.byte_last({photo_byte_last,wav_byte_last,video_byte_last}),

  .source_done_valid({photo_source_done_valid,wav_source_done_valid,video_source_done_valid}),.source_done_ready({photo_source_done_ready,wav_source_done_ready,video_source_done_ready}),

  .source_done_error({photo_source_done_error,wav_source_done_error,video_source_done_error}),.quiescent(files_quiescent),.file_error(files_error),

  .sectors_ok(sectors_ok),.sectors_bad(sectors_bad),.sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat));



 station_photo_files photos(.clk(clk),.rst_n(rst_n),.sd_initialized(sd_initialized),.file_quiescent(files_quiescent[2]),.mem_initialized(memory_initialized),

  .request_valid(photo_request_valid),.request_ready(photo_request_ready),.image_index(photo_index),.cancel(photo_cancel||memory_fault||share_fault),

  .file_request(photo_file_request),.file_cancel(photo_file_cancel),.short_name(photo_short_name),

  .start_valid(photo_start_valid),.start_ready(photo_start_ready),.file_size(photo_file_size),

  .byte_valid(photo_byte_valid),.byte_ready(photo_byte_ready),.byte_data(photo_byte_data),.byte_last(photo_byte_last),

  .source_done_valid(photo_source_done_valid),.source_done_ready(photo_source_done_ready),.source_done_error(photo_source_done_error),

  .descriptor_valid(photo_descriptor_valid),.descriptor_ready(photo_descriptor_ready),.descriptor_error(photo_descriptor_error),.error_code(photo_error),.error_stage(photo_error_stage),

  .descriptor_base(photo_base),.descriptor_slot(photo_slot),.descriptor_generation(photo_generation),

  .release_valid(photo_release_valid),.release_slot(photo_release_slot),.release_generation(photo_release_generation),.clear_fault(photo_clear_fault),

  .busy(photo_busy),.published(photo_published),.pool_fault(photo_pool_fault),.memory_quiet(photo_quiet),

  .rd_valid(prd),.rd_ready(prready),.rd_address(pra),.rd_data_valid(pdv),.rd_data(pdata),.rd_last(plast),.memory_fault(memory_fault||share_fault),

  .mem_wr_valid(pwr),.mem_wr_ready(pwready),.mem_wr_address(pwa),.mem_wr_data(pwd),

  .mem_wr_rsp_valid(pack),.mem_wr_rsp_ready(packready),.mem_wr_rsp_error(perr));

 station_memory_share arbiter(.clk(clk),.rst_n(rst_n),

  .c_wr_valid({pwr,core_mem_wr_valid}),.c_wr_ready({pwready,core_mem_wr_ready}),.c_wr_address({pwa,core_mem_wr_address}),.c_wr_data({pwd,core_mem_wr_data}),

  .c_rsp_valid({pack,core_mem_wr_rsp_valid}),.c_rsp_ready({packready,core_mem_wr_rsp_ready}),.c_rsp_error({perr,core_mem_wr_rsp_error}),

  .c_rd_valid({prd,core_mem_rd_valid}),.c_rd_ready({prready,core_mem_rd_ready}),.c_rd_address({pra,core_mem_rd_address}),

  .c_data_valid({pdv,core_mem_rd_data_valid}),.c_data({pdata,core_mem_rd_data}),.c_last({plast,core_mem_rd_last}),

  .wr_valid(bwr),.wr_ready(bwready),.wr_address(bwa),.wr_data(bwd),.rsp_valid(back),.rsp_ready(backready),.rsp_error(berr),

  .rd_valid(brd),.rd_ready(brready),.rd_address(bra),.data_valid(bdv),.data(bdata),.last(blast),.quiet(share_quiet),.fault(share_fault));

 station_sdram_backend #(.POWER_CYCLES(MEMORY_POWER),.REFRESH_CYCLES(MEMORY_REFRESH)) memory(

  .clk(clk),.forwarded_clk(forwarded_clk),.arst_n(arst_n),.initialized(memory_initialized),

  .wr_valid(bwr),.wr_ready(bwready),.wr_address(bwa),.wr_data(bwd),.wr_rsp_valid(back),.wr_rsp_ready(backready),.wr_rsp_error(berr),

  .rd_valid(brd),.rd_ready(brready),.rd_address(bra),.rd_data_valid(bdv),.rd_data(bdata),.rd_last(blast),

  .quiet(memory_backend_quiet),.fault(memory_fault),.write_acks(memory_write_acks),.read_bursts(memory_read_bursts),.refresh_count(memory_refreshes),

  .sdram_clk(sdram_clk),.sdram_ras_n(sdram_ras_n),.sdram_cas_n(sdram_cas_n),.sdram_we_n(sdram_we_n),

  .sdram_addr(sdram_addr),.sdram_ba(sdram_ba),.sdram_dqm(sdram_dqm),.sdram_dq(sdram_dq));




endmodule
