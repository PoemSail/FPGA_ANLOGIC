// Structural adaptation of station_media_system; original preserved.

// Original SHA256: 97ed23e2675e34d8214e0e7f7b30c61a6efccb93e734db976eae626ec26086fd

`timescale 1ns/1ps

// Native SD4/FAT contexts -> actual station video/music/FFT/UI -> HDMI.

// Native SD4/FAT/photo pool/shared SDRAM connected; PLL and photo display remain external.

// Common reset required across this module and the outstanding memory backend.

module station_picture_memory_system #(





 parameter integer CLOCK_HZ=50000000,CLOCKS_PER_MS=50000,

 parameter integer KEY_FILTER_CYCLES=1000000,KEY_LONG_CYCLES=50000000,KEY_CLEAR_CYCLES=100000000,

 parameter integer PIR_WARMUP_MS=60000,PIR_HIGH_MS=50,PIR_LOW_MS=100,PIR_HOLD_MS=20000,MANUAL_SERVICE_MS=20000,

 parameter integer LIGHT_SAMPLE_MS=10,LIGHT_STABLE_SAMPLES=50,LIGHT_POLARITY_VALID=0,LIGHT_DARK_LEVEL=1,

 parameter integer WAV_DEPTH=2048,WAV_AW=11,WAV_PREFILL=128,

 parameter integer PCM_AW=15,VIDEO_FIFO_AW=10,VIDEO_FIFO_DEPTH=1024,VIDEO_FIFO_PREFILL=128

,

 parameter integer SD_POWER_WAIT=500000,SD_INIT_TIMEOUT=100000000,SD_TOKEN_TIMEOUT=5000000,

 parameter integer SD_INIT_HALF=64,SD_DATA_HALF=2,

 parameter integer VIDEO_MAX_BYTES=268435456,VIDEO_CHAIN=65536,

 parameter integer WAV_MAX_BYTES=16777216,WAV_CHAIN=8192,DIR_CHAIN=512,PHOTO_MAX_BYTES=4194304,PHOTO_CHAIN=2048,

 parameter integer MEMORY_POWER=10000,MEMORY_REFRESH=150

)(

 input wire bus_clk,

 input wire pixel_clk,

 input wire arst_n,

 input wire [2:0] key_n,

 input wire pir_async,

 input wire light_async,

 input wire video_cancel,output wire [31:0] video_files_completed,output wire memory_quiet,

 input wire memory_clk,output wire memory_initialized,memory_backend_quiet,memory_fault,

 output wire [31:0] memory_write_acks,memory_read_bursts,memory_refreshes,

 output wire sdram_clk,sdram_ras_n,sdram_cas_n,sdram_we_n,

 output wire [10:0] sdram_addr,output wire [1:0] sdram_ba,output wire [3:0] sdram_dqm,inout wire [31:0] sdram_dq,

 input wire photo_request_valid,output wire photo_request_ready,input wire [1:0] photo_index,input wire photo_cancel,

 output wire photo_descriptor_valid,input wire photo_descriptor_ready,output wire photo_descriptor_error,

 output wire [7:0] photo_error,output wire [1:0] photo_error_stage,output wire [20:0] photo_base,

 output wire photo_slot,output wire [15:0] photo_generation,

 input wire photo_release_valid,photo_release_slot,input wire [15:0] photo_release_generation,input wire photo_clear_fault,

 output wire [1:0] photo_busy,photo_published,output wire photo_pool_fault,share_fault,

 input wire photo_pixel_valid,

 input wire [23:0] photo_rgb,

 output wire [11:0] media_x,

 output wire [11:0] media_y,

 output wire media_de,

 output wire photo_next,

 output wire photo_previous,

 output wire [23:0] out_rgb,

 output wire [11:0] out_x,

 output wire [11:0] out_y,

 output wire out_de,

 output wire out_hs,

 output wire out_vs,

 output wire physical_tick,

 output wire audio_valid,

 output wire signed [15:0] audio_left,

 output wire signed [15:0] audio_right,

 output wire [1:0] scene,

 output wire [1:0] requested_scene,

 output wire [1:0] normal_media,

 output wire music_selected,

 output wire music_playing,

 output wire emergency_latched,

 output wire fault,

 output wire video_fault,

 output wire music_fault,

 output wire pixel_fault,

 output wire [3:0] video_error,

 output wire [3:0] music_error,

 output wire [31:0] fft_blocks,

 output wire [31:0] fft_dropped,

 output wire [31:0] music_loops,

 output wire [31:0] video_underflows,

 output wire [63:0] video_content_samples,

 input wire serial_clk,

 output wire [2:0] hdmi_data_p,

 output wire hdmi_clock_p,

 output wire hdmi_cdc_overflow,

 output wire hdmi_packet_overflow,

 output wire hdmi_cadence_error,

 output wire [31:0] hdmi_audio_dropped,

 output wire [31:0] hdmi_audio_packets,

 output wire [31:0] hdmi_acr_packets,

 output wire [31:0] hdmi_info_packets,

 input wire sd_retry_valid,output wire sd_retry_ready,

 output wire sd_initialized,output wire [3:0] sd_error,

 output wire [2:0] files_quiescent,output wire [11:0] files_error,

 output wire [31:0] sectors_ok,sectors_bad,

 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat

);



 wire core_quiet,photo_quiet,share_quiet,storage_quiet;

 wire core_mem_wr_valid,core_mem_wr_ready,core_mem_wr_rsp_valid,core_mem_wr_rsp_ready,core_mem_wr_rsp_error;

 wire core_mem_rd_valid,core_mem_rd_ready,core_mem_rd_data_valid,core_mem_rd_last;

 wire [20:0] core_mem_wr_address,core_mem_rd_address;wire [31:0] core_mem_wr_data,core_mem_rd_data;

 wire pwr,pwready,pack,packready,perr,prd,prready,pdv,plast;

 wire [20:0] pwa,pra;wire [31:0] pwd,pdata;

 wire bwr,bwready,back,backready,berr,brd,brready,bdv,blast;

 wire [20:0] bwa,bra;wire [31:0] bwd,bdata;

 wire photo_file_request,photo_file_cancel,photo_start_valid,photo_start_ready;

 wire photo_byte_valid,photo_byte_ready,photo_byte_last,photo_source_done_valid,photo_source_done_ready,photo_source_done_error;

 wire [31:0] photo_file_size;wire [7:0] photo_byte_data;wire [87:0] photo_short_name;

 assign memory_quiet=core_quiet&&storage_quiet;

 wire video_file_request;

 wire video_start_valid;

 wire [31:0] video_file_size;

 wire video_byte_valid;

 wire video_byte_ready;

 wire [7:0] video_byte_data;

 wire video_byte_last;

 wire video_source_done_valid;

 wire video_source_done_ready;

 wire video_source_done_error;

 wire video_file_cancel;

 wire wav_file_request;

 wire wav_file_cancel;

 wire wav_start_valid;

 wire wav_start_ready;

 wire [31:0] wav_file_size;

 wire wav_byte_valid;

 wire wav_byte_ready;

 wire [7:0] wav_byte_data;

 wire wav_byte_last;

 wire wav_source_done_valid;

 wire wav_source_done_ready;

 wire wav_source_done_error;

 wire storage_rst;reset_sync storage_reset(.clk(bus_clk),.arst_n(arst_n),.rst_n(storage_rst));

 station_system_hdmi #(

  .CLOCK_HZ(CLOCK_HZ),

  .CLOCKS_PER_MS(CLOCKS_PER_MS),

  .KEY_FILTER_CYCLES(KEY_FILTER_CYCLES),

  .KEY_LONG_CYCLES(KEY_LONG_CYCLES),

  .KEY_CLEAR_CYCLES(KEY_CLEAR_CYCLES),

  .PIR_WARMUP_MS(PIR_WARMUP_MS),

  .PIR_HIGH_MS(PIR_HIGH_MS),

  .PIR_LOW_MS(PIR_LOW_MS),

  .PIR_HOLD_MS(PIR_HOLD_MS),

  .MANUAL_SERVICE_MS(MANUAL_SERVICE_MS),

  .LIGHT_SAMPLE_MS(LIGHT_SAMPLE_MS),

  .LIGHT_STABLE_SAMPLES(LIGHT_STABLE_SAMPLES),

  .LIGHT_POLARITY_VALID(LIGHT_POLARITY_VALID),

  .LIGHT_DARK_LEVEL(LIGHT_DARK_LEVEL),

  .WAV_DEPTH(WAV_DEPTH),

  .WAV_AW(WAV_AW),

  .WAV_PREFILL(WAV_PREFILL),

  .PCM_AW(PCM_AW),

  .VIDEO_FIFO_AW(VIDEO_FIFO_AW),

  .VIDEO_FIFO_DEPTH(VIDEO_FIFO_DEPTH),

  .VIDEO_FIFO_PREFILL(VIDEO_FIFO_PREFILL)) station(

  .bus_clk(bus_clk),

  .pixel_clk(pixel_clk),

  .arst_n(arst_n),

  .key_n(key_n),

  .pir_async(pir_async),

  .light_async(light_async),

  .mem_initialized(memory_initialized),

  .video_cancel(video_cancel||memory_fault||share_fault),

  .video_file_request(video_file_request),

  .video_start_valid(video_start_valid),

  .video_file_size(video_file_size),

  .video_byte_valid(video_byte_valid),

  .video_byte_ready(video_byte_ready),

  .video_byte_data(video_byte_data),

  .video_byte_last(video_byte_last),

  .video_source_done_valid(video_source_done_valid),

  .video_source_done_ready(video_source_done_ready),

  .video_source_done_error(video_source_done_error),

  .video_file_cancel(video_file_cancel),

  .video_files_completed(video_files_completed),

  .wav_file_request(wav_file_request),

  .wav_file_cancel(wav_file_cancel),

  .wav_start_valid(wav_start_valid),

  .wav_start_ready(wav_start_ready),

  .wav_file_size(wav_file_size),

  .wav_byte_valid(wav_byte_valid),

  .wav_byte_ready(wav_byte_ready),

  .wav_byte_data(wav_byte_data),

  .wav_byte_last(wav_byte_last),

  .wav_source_done_valid(wav_source_done_valid),

  .wav_source_done_ready(wav_source_done_ready),

  .wav_source_done_error(wav_source_done_error),

  .mem_wr_valid(core_mem_wr_valid),

  .mem_wr_ready(core_mem_wr_ready),

  .mem_wr_address(core_mem_wr_address),

  .mem_wr_data(core_mem_wr_data),

  .mem_wr_rsp_valid(core_mem_wr_rsp_valid),

  .mem_wr_rsp_ready(core_mem_wr_rsp_ready),

  .mem_wr_rsp_error(core_mem_wr_rsp_error),

  .mem_rd_valid(core_mem_rd_valid),

  .mem_rd_ready(core_mem_rd_ready),

  .mem_rd_address(core_mem_rd_address),

  .mem_rd_data_valid(core_mem_rd_data_valid),

  .mem_rd_data(core_mem_rd_data),

  .mem_rd_last(core_mem_rd_last),

  .memory_quiet(core_quiet),

  .photo_pixel_valid(photo_pixel_valid),

  .photo_rgb(photo_rgb),

  .media_x(media_x),

  .media_y(media_y),

  .media_de(media_de),

  .photo_next(photo_next),

  .photo_previous(photo_previous),

  .out_rgb(out_rgb),

  .out_x(out_x),

  .out_y(out_y),

  .out_de(out_de),

  .out_hs(out_hs),

  .out_vs(out_vs),

  .physical_tick(physical_tick),

  .audio_valid(audio_valid),

  .audio_left(audio_left),

  .audio_right(audio_right),

  .scene(scene),

  .requested_scene(requested_scene),

  .normal_media(normal_media),

  .music_selected(music_selected),

  .music_playing(music_playing),

  .emergency_latched(emergency_latched),

  .fault(fault),

  .video_fault(video_fault),

  .music_fault(music_fault),

  .pixel_fault(pixel_fault),

  .video_error(video_error),

  .music_error(music_error),

  .fft_blocks(fft_blocks),

  .fft_dropped(fft_dropped),

  .music_loops(music_loops),

  .video_underflows(video_underflows),

  .video_content_samples(video_content_samples),

  .serial_clk(serial_clk),

  .hdmi_data_p(hdmi_data_p),

  .hdmi_clock_p(hdmi_clock_p),

  .hdmi_cdc_overflow(hdmi_cdc_overflow),

  .hdmi_packet_overflow(hdmi_packet_overflow),

  .hdmi_cadence_error(hdmi_cadence_error),

  .hdmi_audio_dropped(hdmi_audio_dropped),

  .hdmi_audio_packets(hdmi_audio_packets),

  .hdmi_acr_packets(hdmi_acr_packets),

  .hdmi_info_packets(hdmi_info_packets));

 station_picture_storage #(
  .SD_POWER_WAIT(SD_POWER_WAIT),
  .SD_INIT_TIMEOUT(SD_INIT_TIMEOUT),
  .SD_TOKEN_TIMEOUT(SD_TOKEN_TIMEOUT),
  .SD_INIT_HALF(SD_INIT_HALF),
  .SD_DATA_HALF(SD_DATA_HALF),
  .VIDEO_MAX_BYTES(VIDEO_MAX_BYTES),
  .VIDEO_CHAIN(VIDEO_CHAIN),
  .WAV_MAX_BYTES(WAV_MAX_BYTES),
  .WAV_CHAIN(WAV_CHAIN),
  .PHOTO_MAX_BYTES(PHOTO_MAX_BYTES),
  .PHOTO_CHAIN(PHOTO_CHAIN),
  .DIR_CHAIN(DIR_CHAIN),
  .MEMORY_POWER(MEMORY_POWER),
  .MEMORY_REFRESH(MEMORY_REFRESH)) storage_system(
  .clk(bus_clk),
  .rst_n(storage_rst),
  .arst_n(arst_n),
  .forwarded_clk(memory_clk),
  .file_request({wav_file_request,video_file_request}),
  .file_cancel({wav_file_cancel,video_file_cancel}),
  .start_valid({wav_start_valid,video_start_valid}),
  .start_ready({wav_start_ready,video_file_request}),
  .file_size({wav_file_size,video_file_size}),
  .byte_valid({wav_byte_valid,video_byte_valid}),
  .byte_ready({wav_byte_ready,video_byte_ready}),
  .byte_data({wav_byte_data,video_byte_data}),
  .byte_last({wav_byte_last,video_byte_last}),
  .source_done_valid({wav_source_done_valid,video_source_done_valid}),
  .source_done_ready({wav_source_done_ready,video_source_done_ready}),
  .source_done_error({wav_source_done_error,video_source_done_error}),
  .core_mem_wr_valid(core_mem_wr_valid),
  .core_mem_wr_ready(core_mem_wr_ready),
  .core_mem_wr_address(core_mem_wr_address),
  .core_mem_wr_data(core_mem_wr_data),
  .core_mem_wr_rsp_valid(core_mem_wr_rsp_valid),
  .core_mem_wr_rsp_ready(core_mem_wr_rsp_ready),
  .core_mem_wr_rsp_error(core_mem_wr_rsp_error),
  .core_mem_rd_valid(core_mem_rd_valid),
  .core_mem_rd_ready(core_mem_rd_ready),
  .core_mem_rd_address(core_mem_rd_address),
  .core_mem_rd_data_valid(core_mem_rd_data_valid),
  .core_mem_rd_data(core_mem_rd_data),
  .core_mem_rd_last(core_mem_rd_last),
  .photo_request_valid(photo_request_valid),
  .photo_request_ready(photo_request_ready),
  .photo_index(photo_index),
  .photo_cancel(photo_cancel),
  .photo_descriptor_valid(photo_descriptor_valid),
  .photo_descriptor_ready(photo_descriptor_ready),
  .photo_descriptor_error(photo_descriptor_error),
  .photo_error(photo_error),
  .photo_error_stage(photo_error_stage),
  .photo_base(photo_base),
  .photo_slot(photo_slot),
  .photo_generation(photo_generation),
  .photo_release_valid(photo_release_valid),
  .photo_release_slot(photo_release_slot),
  .photo_release_generation(photo_release_generation),
  .photo_clear_fault(photo_clear_fault),
  .photo_busy(photo_busy),
  .photo_published(photo_published),
  .photo_pool_fault(photo_pool_fault),
  .share_fault(share_fault),
  .sd_retry_valid(sd_retry_valid),
  .sd_retry_ready(sd_retry_ready),
  .sd_initialized(sd_initialized),
  .sd_error(sd_error),
  .files_quiescent(files_quiescent),
  .files_error(files_error),
  .sectors_ok(sectors_ok),
  .sectors_bad(sectors_bad),
  .sd_clk(sd_clk),
  .sd_cmd(sd_cmd),
  .sd_dat(sd_dat),
  .memory_initialized(memory_initialized),
  .memory_backend_quiet(memory_backend_quiet),
  .memory_fault(memory_fault),
  .memory_quiet(storage_quiet),
  .memory_write_acks(memory_write_acks),
  .memory_read_bursts(memory_read_bursts),
  .memory_refreshes(memory_refreshes),
  .sdram_clk(sdram_clk),
  .sdram_ras_n(sdram_ras_n),
  .sdram_cas_n(sdram_cas_n),
  .sdram_we_n(sdram_we_n),
  .sdram_addr(sdram_addr),
  .sdram_ba(sdram_ba),
  .sdram_dqm(sdram_dqm),
  .sdram_dq(sdram_dq));
endmodule
