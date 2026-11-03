// Native R12 fast_stream/read_count1 CRC quarantine enables overlapping cache drain.
`timescale 1ns/1ps
// Same native SD4 controller, three independently backpressured file contexts.
module station_sd_three_files #(
 parameter integer POWER_WAIT_CYCLES=500000,INIT_TIMEOUT_CYCLES=100000000,TOKEN_TIMEOUT_CYCLES=5000000,
 parameter integer INIT_HALF_PERIOD=64,DATA_HALF_PERIOD=2,
 parameter integer VIDEO_MAX_BYTES=268435456,VIDEO_CHAIN=65536,WAV_MAX_BYTES=16777216,WAV_CHAIN=8192,
 parameter integer PHOTO_MAX_BYTES=4194304,PHOTO_CHAIN=2048,DIR_CHAIN=512
)(
 input wire clk,rst_n,retry_valid,output wire retry_ready,
 output wire initialized,output wire [3:0] sd_error,input wire [87:0] photo_short_name,
 input wire [2:0] file_request,file_cancel,
 output wire [2:0] start_valid,input wire [2:0] start_ready,output wire [95:0] file_size,
 output wire [2:0] byte_valid,input wire [2:0] byte_ready,output wire [23:0] byte_data,output wire [2:0] byte_last,
 output wire [2:0] source_done_valid,input wire [2:0] source_done_ready,output wire [2:0] source_done_error,
 output wire [2:0] quiescent,output wire [11:0] file_error,
 output wire [31:0] sectors_ok,sectors_bad,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat
);
 wire rv,rr,dv,dr,last,done,done_ready,done_error,card_retry_ready,busy;wire [31:0] lba;wire [7:0] data;
 assign retry_ready=rst_n&&card_retry_ready&&(&quiescent)&&!(|file_request);
 sdhc_native_r12 #(.BUS_WIDTH(4),.POWER_WAIT_CYCLES(POWER_WAIT_CYCLES),.INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),
  .TOKEN_TIMEOUT_CYCLES(TOKEN_TIMEOUT_CYCLES),.INIT_HALF_PERIOD(INIT_HALF_PERIOD),.DATA_HALF_PERIOD(DATA_HALF_PERIOD)) card(
  .fast_stream(1'b1),.read_count(8'd1),.clk(clk),.rst_n(rst_n),.retry_valid(retry_valid&&retry_ready),.retry_ready(card_retry_ready),
  .initialized(initialized),.busy(busy),.error_code(sd_error),.read_valid(rv),.read_ready(rr),.read_lba(lba),
  .data_valid(dv),.data_ready(dr),.data(data),.data_last(last),.done_valid(done),.done_ready(done_ready),.done_error(done_error),
  .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat));
 station_three_files #(.BACKEND_QUARANTINED(1),.VIDEO_MAX_BYTES(VIDEO_MAX_BYTES),.VIDEO_CHAIN(VIDEO_CHAIN),.WAV_MAX_BYTES(WAV_MAX_BYTES),.WAV_CHAIN(WAV_CHAIN),
  .PHOTO_MAX_BYTES(PHOTO_MAX_BYTES),.PHOTO_CHAIN(PHOTO_CHAIN),.DIR_CHAIN(DIR_CHAIN)) files(
  .clk(clk),.rst_n(rst_n),.backend_failed(!initialized&&sd_error!=0),.photo_short_name(photo_short_name),
  .file_request(file_request),.file_cancel(file_cancel),.start_valid(start_valid),.start_ready(start_ready),.file_size(file_size),
  .byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .quiescent(quiescent),.file_error(file_error),.read_valid(rv),.read_ready(rr),.read_lba(lba),
  .data_valid(dv),.data_ready(dr),.data(data),.data_last(last),.done_valid(done),.done_ready(done_ready),.done_error(done_error),
  .sectors_ok(sectors_ok),.sectors_bad(sectors_bad));
endmodule
