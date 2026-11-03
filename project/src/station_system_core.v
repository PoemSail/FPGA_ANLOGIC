`timescale 1ns/1ps
// Integrated business + pixel core. Physical-key passenger WAV/FFT service,
// R56 video with shared sample phase, coherent UI and 960x540 media viewport.
// Two file contexts are intentional: a paused R56 session cannot block WAV.
// External FAT/SD arbitration and physical memory/HDMI are not in this module.
module station_system_core #(
 parameter integer CLOCK_HZ=50000000,CLOCKS_PER_MS=50000,
 parameter integer KEY_FILTER_CYCLES=1000000,KEY_LONG_CYCLES=50000000,KEY_CLEAR_CYCLES=100000000,
 parameter integer PIR_WARMUP_MS=60000,PIR_HIGH_MS=50,PIR_LOW_MS=100,PIR_HOLD_MS=20000,MANUAL_SERVICE_MS=20000,
 parameter integer LIGHT_SAMPLE_MS=10,LIGHT_STABLE_SAMPLES=50,LIGHT_POLARITY_VALID=0,LIGHT_DARK_LEVEL=1,
 parameter integer WAV_DEPTH=2048,WAV_AW=11,WAV_PREFILL=128,
 parameter integer PCM_AW=15,VIDEO_FIFO_AW=10,VIDEO_FIFO_DEPTH=1024,VIDEO_FIFO_PREFILL=128
)(
 input wire bus_clk,pixel_clk,arst_n,input wire [2:0] key_n,input wire pir_async,light_async,
 input wire mem_initialized,video_cancel,
 output wire video_file_request,input wire video_start_valid,input wire [31:0] video_file_size,
 input wire video_byte_valid,output wire video_byte_ready,input wire [7:0] video_byte_data,input wire video_byte_last,
 input wire video_source_done_valid,output wire video_source_done_ready,input wire video_source_done_error,
 output wire video_file_cancel,output wire [31:0] video_files_completed,
 output wire wav_file_request,wav_file_cancel,input wire wav_start_valid,output wire wav_start_ready,input wire [31:0] wav_file_size,
 input wire wav_byte_valid,output wire wav_byte_ready,input wire [7:0] wav_byte_data,input wire wav_byte_last,
 input wire wav_source_done_valid,output wire wav_source_done_ready,input wire wav_source_done_error,
 output wire mem_wr_valid,input wire mem_wr_ready,output wire [20:0] mem_wr_address,output wire [31:0] mem_wr_data,
 input wire mem_wr_rsp_valid,output wire mem_wr_rsp_ready,input wire mem_wr_rsp_error,
 output wire mem_rd_valid,input wire mem_rd_ready,output wire [20:0] mem_rd_address,
 input wire mem_rd_data_valid,input wire [31:0] mem_rd_data,input wire mem_rd_last,
 output wire memory_quiet,
 // Future BMP path supplies RGB aligned to media_x/y/de; absent pixels black.
 input wire photo_pixel_valid,input wire [23:0] photo_rgb,
 output wire [11:0] media_x,media_y,output wire media_de,
 output wire photo_next,photo_previous,
 output wire [23:0] out_rgb,output wire [11:0] out_x,out_y,output wire out_de,out_hs,out_vs,
 output wire physical_tick,audio_valid,output wire signed [15:0] audio_left,audio_right,
 output wire [1:0] scene,requested_scene,normal_media,
 output wire music_selected,music_playing,emergency_latched,
 output wire fault,video_fault,music_fault,pixel_fault,output wire [3:0] video_error,music_error,
 output wire [31:0] fft_blocks,fft_dropped,music_loops,video_underflows,
 output wire [63:0] video_content_samples
);
 wire brst,prst;reset_sync br(.clk(bus_clk),.arst_n(arst_n),.rst_n(brst));
 reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 wire control_frame_commit,normal_play_enable,normal_pcm_valid,video_pop;
 wire signed [15:0] normal_left,normal_right;
 wire [2:0] menu;wire signed [7:0] brightness;wire [8:0] contrast;wire [3:0] volume;
 wire [1:0] transition;wire automatic_brightness,pir_ready,pir_service,light_known,dark;
 wire [255:0] levels;wire spectrum_valid;wire [31:0] fft_accepted,wav_underruns;
 wire [63:0] video_pts;wire raw_hs,raw_vs;wire [23:0] video_rgb;
 assign fault=video_fault||music_fault;
 station_passenger_core #(.CLOCK_HZ(CLOCK_HZ),.CLOCKS_PER_MS(CLOCKS_PER_MS),
  .KEY_FILTER_CYCLES(KEY_FILTER_CYCLES),.KEY_LONG_CYCLES(KEY_LONG_CYCLES),.KEY_CLEAR_CYCLES(KEY_CLEAR_CYCLES),
  .PIR_WARMUP_MS(PIR_WARMUP_MS),.PIR_HIGH_MS(PIR_HIGH_MS),.PIR_LOW_MS(PIR_LOW_MS),.PIR_HOLD_MS(PIR_HOLD_MS),
  .MANUAL_SERVICE_MS(MANUAL_SERVICE_MS),.LIGHT_SAMPLE_MS(LIGHT_SAMPLE_MS),.LIGHT_STABLE_SAMPLES(LIGHT_STABLE_SAMPLES),
  .LIGHT_POLARITY_VALID(LIGHT_POLARITY_VALID),.LIGHT_DARK_LEVEL(LIGHT_DARK_LEVEL),
  .PCM_DEPTH(WAV_DEPTH),.PCM_AW(WAV_AW),.PCM_PREFILL(WAV_PREFILL)) passenger(
  .clk(bus_clk),.reset_n_async(arst_n),.key_n(key_n),.pir_async(pir_async),.light_async(light_async),
  .frame_commit(control_frame_commit),.media_fault(video_fault),
  .file_request(wav_file_request),.file_cancel(wav_file_cancel),.file_start_valid(wav_start_valid),.file_start_ready(wav_start_ready),
  .file_size(wav_file_size),.byte_valid(wav_byte_valid),.byte_ready(wav_byte_ready),.byte_data(wav_byte_data),.byte_last(wav_byte_last),
  .source_done_valid(wav_source_done_valid),.source_done_ready(wav_source_done_ready),.source_done_error(wav_source_done_error),
  .normal_pcm_valid(normal_pcm_valid),.normal_left(normal_left),.normal_right(normal_right),
  .normal_play_enable(normal_play_enable),.physical_tick(physical_tick),.audio_valid(audio_valid),.audio_left(audio_left),.audio_right(audio_right),
  .scene(scene),.requested_scene(requested_scene),.normal_media(normal_media),.music_selected(music_selected),.music_playing(music_playing),
  .emergency_latched(emergency_latched),.menu(menu),.brightness(brightness),.contrast(contrast),.volume(volume),.transition(transition),
  .photo_next(photo_next),.photo_previous(photo_previous),.auto_brightness_active(automatic_brightness),.pir_warmup_done(pir_ready),
  .pir_service(pir_service),.light_known(light_known),.dark(dark),.spectrum_levels(levels),.spectrum_valid(spectrum_valid),
  .fft_blocks(fft_blocks),.fft_dropped(fft_dropped),.fft_accepted(fft_accepted),.audio_underruns(wav_underruns),
  .music_loops(music_loops),.music_fault(music_fault),.music_error(music_error));
 station_video_display #(.MEDIA_VIEWPORT(1),.PCM_AW(PCM_AW),.FIFO_AW(VIDEO_FIFO_AW),.FIFO_DEPTH(VIDEO_FIFO_DEPTH),.FIFO_PREFILL(VIDEO_FIFO_PREFILL)) video(
  .bus_clk(bus_clk),.pixel_clk(pixel_clk),.arst_n(arst_n),.enabled(1'b1),
  .paused(!normal_play_enable||normal_media!=2),.cancel(video_cancel),.mem_initialized(mem_initialized),.physical_tick(physical_tick),
  .file_request(video_file_request),.file_start_valid(video_start_valid),.file_size(video_file_size),
  .byte_valid(video_byte_valid),.byte_ready(video_byte_ready),.byte_data(video_byte_data),.byte_last(video_byte_last),
  .source_done_valid(video_source_done_valid),.source_done_ready(video_source_done_ready),.source_done_error(video_source_done_error),
  .file_cancel(video_file_cancel),.files_completed(video_files_completed),.fault(video_fault),.file_error(video_error),
  .sample_valid(normal_pcm_valid),.sample_left(normal_left),.sample_right(normal_right),.content_pop(video_pop),
  .content_samples(video_content_samples),.display_pts(video_pts),
  .mem_wr_valid(mem_wr_valid),.mem_wr_ready(mem_wr_ready),.mem_wr_address(mem_wr_address),.mem_wr_data(mem_wr_data),
  .mem_wr_rsp_valid(mem_wr_rsp_valid),.mem_wr_rsp_ready(mem_wr_rsp_ready),.mem_wr_rsp_error(mem_wr_rsp_error),
  .mem_rd_valid(mem_rd_valid),.mem_rd_ready(mem_rd_ready),.mem_rd_address(mem_rd_address),
  .mem_rd_data_valid(mem_rd_data_valid),.mem_rd_data(mem_rd_data),.mem_rd_last(mem_rd_last),.memory_quiet(memory_quiet),
  .control_frame_commit(control_frame_commit),.out_rgb(video_rgb),.out_x(media_x),.out_y(media_y),.out_de(media_de),.out_hs(raw_hs),.out_vs(raw_vs),
  .pixel_fault(pixel_fault),.underflow_lines(video_underflows));
 wire [9:0] scroll;wire [7:0] arrival1,arrival2;
 station_demo_status #(.CLOCKS_PER_MS(CLOCKS_PER_MS)) status(.clk(bus_clk),.rst_n(brst),.frame_commit(control_frame_commit),
  .scroll(scroll),.arrival1(arrival1),.arrival2(arrival2));
 wire [316:0] snapshot={scene,normal_media,transition,music_selected,music_playing,menu,volume,brightness,contrast,
  automatic_brightness,light_known,dark,scroll,arrival1,arrival2,levels};
 wire [316:0] pixel_snapshot;wire snapshot_ready,pixel_snapshot_valid;
 station_frame_mailbox #(.WIDTH(317)) ui_mailbox(.src_clk(bus_clk),.dst_clk(pixel_clk),.arst_n(arst_n),
  .src_data(snapshot),.src_valid(1'b1),.src_ready(snapshot_ready),.dst_frame(media_y>=720),
  .dst_data(pixel_snapshot),.dst_valid(pixel_snapshot_valid));
 wire [1:0] p_scene,p_media,p_transition;wire p_selected,p_playing;wire [2:0] p_menu;wire [3:0] p_volume;
 wire signed [7:0] p_brightness;wire [8:0] p_contrast;wire p_auto,p_known,p_dark;
 wire [9:0] p_scroll;wire [7:0] p_arrival1,p_arrival2;wire [255:0] p_levels;
 assign {p_scene,p_media,p_transition,p_selected,p_playing,p_menu,p_volume,p_brightness,p_contrast,
  p_auto,p_known,p_dark,p_scroll,p_arrival1,p_arrival2,p_levels}=pixel_snapshot;
 wire [23:0] selected_media=p_media==0?(photo_pixel_valid?photo_rgb:24'd0):video_rgb;
 wire view_valid;
 station_service_view view(.clk(pixel_clk),.rst_n(prst),.in_valid(1'b1),.in_de(media_de),.in_hs(raw_hs),.in_vs(raw_vs),
  .in_x(media_x),.in_y(media_y),.media_rgb(selected_media),.scene(p_scene),
  .normal_media(pixel_snapshot_valid?p_media:2'd2),.transition(p_transition),.music_selected(p_selected),.music_playing(p_playing),
  .levels(p_levels),.menu(p_menu),.volume(pixel_snapshot_valid?p_volume:4'd8),.brightness(p_brightness),
  .contrast(pixel_snapshot_valid?p_contrast:9'd256),.auto_brightness(p_auto),.light_known(p_known),.dark(p_dark),
  .scroll(p_scroll),.arrival1(p_arrival1),.arrival2(p_arrival2),
  .out_valid(view_valid),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),.out_x(out_x),.out_y(out_y),.out_rgb(out_rgb));
endmodule
