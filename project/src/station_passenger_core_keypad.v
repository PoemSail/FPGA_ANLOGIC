// Latest-pin matrix derivative; original source retained.
// Unselected fixed-test-tone derivative; parent SHA256 2d5565ace061dcc4f50ded5874aaa9564b6d191695a40c30ee9566e261a04d12
// Global-recovery derivative; tested predecessor preserved.
// Persistent business/tone/tick; only WAV/FFT use media reset.
// Scheduled-station derivative; previous source preserved.
`timescale 1ns/1ps
// Board-independent integration of physical buttons, service policy, WAV and real FFT.
// Normal/video PCM is already paced one clock after physical_tick by its future reader.
module station_passenger_core_global_recovery #(
 parameter integer CLOCK_HZ=50000000,
 parameter integer CLOCKS_PER_MS=50000,
 parameter integer KEY_FILTER_CYCLES=1000000,KEY_LONG_CYCLES=50000000,KEY_CLEAR_CYCLES=100000000,
 parameter integer PIR_WARMUP_MS=60000,PIR_HIGH_MS=50,PIR_LOW_MS=100,PIR_HOLD_MS=20000,
 parameter integer MANUAL_SERVICE_MS=20000,LIGHT_SAMPLE_MS=10,LIGHT_STABLE_SAMPLES=50,
 parameter integer LIGHT_POLARITY_VALID=0,LIGHT_DARK_LEVEL=1,
 parameter integer PCM_DEPTH=2048,PCM_AW=11,PCM_PREFILL=128,STREAM_SPECTRUM=0
)(input wire clk,reset_n_async,input wire [2:0] key_n,input wire pir_async,light_async,
 input wire keypad_valid,input wire [3:0] keypad_code,
 input wire keypad_long_valid,input wire [3:0] keypad_long_code,
 input wire frame_commit,input wire media_fault,photo_load_error,
 input wire media_reset_n,hold_media,cancel_media,source_quiet,
 input wire recovery_failed,retry_ready,output wire global_retry,
 output wire music_quiescent,music_prefilled,business_tick_ms,
 output wire photo_auto_start,photo_retry,
 output wire file_request,file_cancel,input wire file_start_valid,output wire file_start_ready,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 input wire normal_pcm_valid,input wire signed [15:0] normal_left,normal_right,
 output wire normal_play_enable,output wire physical_tick,
 output reg audio_valid,output reg signed [15:0] audio_left,audio_right,
 output wire [1:0] scene,requested_scene,normal_media,
 output wire music_selected,music_playing,output wire emergency_latched,
 output wire [2:0] menu,output wire signed [7:0] brightness,output wire [8:0] contrast,
 output wire [3:0] volume,output wire [1:0] transition,output wire photo_next,photo_previous,
 output wire auto_brightness_active,pir_warmup_done,pir_service,light_known,dark,
 output wire spectrum_height_valid,output wire [4:0] spectrum_height_index,output wire [7:0] spectrum_height,
 output wire [255:0] spectrum_levels,output wire spectrum_valid,
 output wire [31:0] fft_blocks,fft_dropped,fft_accepted,audio_underruns,music_loops,
 output wire music_fault,output wire [3:0] music_error
);
 wire rst_n;reset_sync resetter(.clk(clk),.arst_n(reset_n_async),.rst_n(rst_n));
 wire media_rst;reset_sync media_resetter(.clk(clk),.arst_n(reset_n_async&&media_reset_n),.rst_n(media_rst));
 wire business_play_enable;assign normal_play_enable=business_play_enable&&!hold_media;
 wire [2:0] short_key,long_key;wire emergency_set,emergency_clear,manual_service,manual_return,retry_music;
 wire alert;
 // F4 retries a latched global failure, without changing the user's pause
 // intent. Busy/held requests are still filtered by the recovery manager.
 assign global_retry=rst_n&&(short_key[2]||(keypad_valid&&keypad_code==4))&&recovery_failed&&retry_ready&&!alert;
 wire [2:0] user_short={short_key[2]&&!recovery_failed,short_key[1:0]};
 // A fresh D press while already latched arms clearing. The initial D
 // press that sets an alarm can never clear that alarm by simply being held.
 reg matrix_emergency_set,matrix_emergency_clear,matrix_clear_armed;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin matrix_emergency_set<=0;matrix_emergency_clear<=0;matrix_clear_armed<=0;end
  else begin
   matrix_emergency_set<=0;matrix_emergency_clear<=0;
   if(!emergency_latched)matrix_clear_armed<=0;
   if(keypad_valid&&keypad_code==15)begin
    if(!emergency_latched)matrix_emergency_set<=1;
    else matrix_clear_armed<=1;
   end
   if(keypad_long_valid&&keypad_long_code==15&&emergency_latched&&matrix_clear_armed)begin
    matrix_emergency_clear<=1;matrix_clear_armed<=0;
   end
  end
 end
 wire normal_playing,auto_b;wire signed [7:0] manual_b;
 station_panel_keys #(.FILTER_CYCLES(KEY_FILTER_CYCLES),.LONG_CYCLES(KEY_LONG_CYCLES),.CLEAR_CYCLES(KEY_CLEAR_CYCLES)) keys(
  .clk(clk),.rst_n(rst_n),.key_n(key_n),.emergency_latched(emergency_latched),
  .short_press(short_key),.long_press(long_key),.emergency_set(emergency_set),.emergency_clear(emergency_clear));
 station_user_control_scheduled users(.clk(clk),.rst_n(rst_n),.frame_commit(frame_commit),
  .short_press(user_short),.long_press(long_key),
  .keypad_valid(keypad_valid&&!(recovery_failed&&keypad_code==4)),.keypad_code(keypad_code),.emergency_active(alert),.active_scene(scene),.music_fault(music_fault),.photo_load_error(photo_load_error),.photo_auto_start(photo_auto_start),.photo_retry(photo_retry),
  .manual_service_pulse(manual_service),.manual_return_pulse(manual_return),.music_selected(music_selected),.music_playing(music_playing),.normal_playing(normal_playing),
  .normal_media(normal_media),.menu(menu),.auto_brightness(auto_b),.manual_brightness(manual_b),
  .contrast(contrast),.volume(volume),.transition(transition),.photo_next(photo_next),.photo_previous(photo_previous),.retry_music(retry_music));
 wire wav_chosen=music_selected||(normal_media==1);
 wire relevant_fault=media_fault||recovery_failed||(wav_chosen&&music_fault);
 station_control_unit_recovery #(.CLOCKS_PER_MS(CLOCKS_PER_MS),.ENABLE_MANUAL_HOLD(1),
  .PIR_WARMUP_MS(PIR_WARMUP_MS),.PIR_HIGH_MS(PIR_HIGH_MS),.PIR_LOW_MS(PIR_LOW_MS),.PIR_HOLD_MS(PIR_HOLD_MS),
  .MANUAL_SERVICE_MS(MANUAL_SERVICE_MS),.LIGHT_SAMPLE_MS(LIGHT_SAMPLE_MS),.LIGHT_STABLE_SAMPLES(LIGHT_STABLE_SAMPLES),
  .LIGHT_POLARITY_VALID(LIGHT_POLARITY_VALID),.LIGHT_DARK_LEVEL(LIGHT_DARK_LEVEL)) control(
  .clk(clk),.reset_n_async(reset_n_async),.pir_async(pir_async),.light_async(light_async),.frame_commit(frame_commit),
  .manual_service_pulse(manual_service),.manual_return_pulse(manual_return),.service_hold(music_selected),.emergency_set(emergency_set||matrix_emergency_set),.emergency_clear(emergency_clear||matrix_emergency_clear),
  .media_fault(relevant_fault),.user_playing(normal_playing),.auto_brightness_enable(auto_b),.manual_brightness(manual_b),
  .pir_warmup_done(pir_warmup_done),.pir_motion(),.pir_service(pir_service),.light_known(light_known),.dark(dark),
  .auto_brightness_active(auto_brightness_active),.active_brightness(brightness),.emergency_latched(emergency_latched),
  .active_scene(scene),.requested_scene(requested_scene),.content_play_enable(business_play_enable),.alert_enable(alert),.tick_ms(business_tick_ms));
 reg [31:0] sample_acc;wire [32:0] sample_sum={1'b0,sample_acc}+33'd48000;
 assign physical_tick=rst_n&&sample_sum>=CLOCK_HZ;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)sample_acc<=0;
  else sample_acc<=physical_tick?sample_sum-CLOCK_HZ:sample_sum;
 end
 wire calibration_mode=(menu==7);
 wire wav_allowed=!calibration_mode&&!hold_media&&music_playing&&!relevant_fault&&!alert&&
  (scene<2&&requested_scene<2&&(music_selected||normal_media==1));
 wire wav_sample_valid;wire signed [15:0] wav_l,wav_r;
 station_wav_player_quiescent #(.DEPTH(PCM_DEPTH),.PREFILL(PCM_PREFILL),.AW(PCM_AW)) music(
  .clk(clk),.rst_n(media_rst),.cancel(cancel_media),.source_quiet(source_quiet),.quiescent(music_quiescent),.prefilled(music_prefilled),.enable(wav_chosen),.play_enable(wav_allowed),.retry(retry_music),.physical_tick(physical_tick),
  .file_request(file_request),.file_cancel(file_cancel),.file_start_valid(file_start_valid),.file_start_ready(file_start_ready),
  .file_size(file_size),.byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .sample_valid(wav_sample_valid),.sample_left(wav_l),.sample_right(wav_r),.content_pop(),.fault(music_fault),.error_code(music_error),
  .fifo_level(),.underruns(audio_underruns),.loops(music_loops));
 wire tone_busy,tone_valid,tone_active,tone_ready;wire signed [15:0] tone;
 // Stable reset: combinational alert priority must never drive an async
 // reset pin. Each alert rising edge requests a fresh/retriggered tone.
 reg [13:0] gap;reg alert_previous;
 wire tone_request=alert&&(!alert_previous||(!tone_busy&&gap==0));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin gap<=0;alert_previous<=0;end
  else begin
   alert_previous<=alert;
   if(!alert)gap<=0;
   else if(tone_busy||(tone_request&&tone_ready))gap<=12000;
   else if(physical_tick&&gap!=0)gap<=gap-1'b1;
  end
 end
 // Emergency tone always uses maximum gain, preserving the user's media volume.
 notification_tone_r21 tone_source(.clk(clk),.rst_n(rst_n),.sample_tick(physical_tick),
  .request_valid(tone_request),.request_ready(tone_ready),.volume(4'd15),.active(tone_busy),
  .sample_valid(tone_valid),.sample_active(tone_active),.sample(tone));
 reg tick_delayed;
 wire calibration_allowed=calibration_mode&&!hold_media&&!relevant_fault&&!alert&&scene<2&&requested_scene<2;
 wire calibration_valid;wire signed [15:0] calibration_pcm;
 station_calibration_tone calibration(.clk(clk),.rst_n(rst_n),.physical_tick(physical_tick),
  .enable(calibration_allowed),.sample_valid(calibration_valid),.sample(calibration_pcm));
 wire signed [15:0] raw_l=calibration_mode?calibration_pcm:(wav_chosen?wav_l:normal_left);
 wire signed [15:0] raw_r=calibration_mode?calibration_pcm:(wav_chosen?wav_r:normal_right);
 wire valid_content=calibration_mode?(calibration_valid&&calibration_allowed):wav_chosen?(wav_sample_valid&&wav_allowed):(normal_pcm_valid&&normal_play_enable&&normal_media==2);
 wire signed [20:0] gain_l=raw_l*$signed({1'b0,volume});
 wire signed [20:0] gain_r=raw_r*$signed({1'b0,volume});
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin tick_delayed<=0;audio_valid<=0;audio_left<=0;audio_right<=0;end
  else begin
   tick_delayed<=physical_tick;audio_valid<=tick_delayed;
   if(tick_delayed)begin
    if(alert)begin audio_left<=tone_valid?tone:16'sd0;audio_right<=tone_valid?tone:16'sd0;end
    else begin audio_left<=valid_content?(gain_l>>>4):16'sd0;audio_right<=valid_content?(gain_r>>>4):16'sd0;end
   end
  end
 end
 station_spectrum #(.STREAM_OUTPUT(STREAM_SPECTRUM)) analyzer(.clk(clk),.rst_n(media_rst),.sample_valid(audio_valid),.left(audio_left),.right(audio_right),
  .height_valid(spectrum_height_valid),.height_index(spectrum_height_index),.height(spectrum_height),.levels(spectrum_levels),.snapshot_valid(spectrum_valid),.blocks(fft_blocks),.dropped_samples(fft_dropped),.accepted_samples(fft_accepted));
endmodule
