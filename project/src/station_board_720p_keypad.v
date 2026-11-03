// Matrix+enabled sensors;25MHz reference; user-confirmed latest IO.
`timescale 1ns/1ps
module station_board_720p #(
 parameter integer PIR_PIN_VALID=1,LIGHT_POLARITY_VALID=1,LIGHT_DARK_LEVEL=1
)(
 input wire clk_25m,rst_n,input wire [2:0] key_n,
 input wire pir_async,light_async,
 input wire [3:0] keypad_cols_n,output wire [3:0] keypad_rows_n,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat,
 output wire [2:0] hdmi_data_p,output wire hdmi_clock_p,output wire [3:0] led_n
);
 wire bus_clk,pixel_clk,serial_clk,memory_clk,primary_locked,video_locked,logic_reset_n;
 station_720p_pll clocks(.refclk(clk_25m),.reset(!rst_n),.bus_clk(bus_clk),.pixel_clk(pixel_clk),
  .serial_clk(serial_clk),.memory_clk(memory_clk),.primary_locked(primary_locked),.video_locked(video_locked));
 station_clock_reset_guard guard(.refclk(clk_25m),.reset_n(rst_n),.primary_locked(primary_locked),.video_locked(video_locked),.logic_reset_n(logic_reset_n));
 wire keypad_rst_n,keypad_valid,keypad_long_valid;
 wire [3:0] keypad_code,keypad_long_code;
 reset_sync keypad_reset(.clk(bus_clk),.arst_n(logic_reset_n),.rst_n(keypad_rst_n));
 station_matrix_keypad #(.LONG_PRESS_CYCLES(100000000)) keypad(
  .clk(bus_clk),.rst_n(keypad_rst_n),.col_n(keypad_cols_n),.row_n(keypad_rows_n),
  .key_valid(keypad_valid),.key_code(keypad_code),
  .key_long_valid(keypad_long_valid),.key_long_code(keypad_long_code));
 wire sc,sr,ss,sw;wire [10:0] sa;wire [1:0] sb;wire [3:0] sm;wire [31:0] dq;
 wire fault,sd_initialized,music_selected,music_playing,emergency_latched;
 // Latest user-bound sensor locations; active-high PIR, DO1=dark.
 wire pir_input=PIR_PIN_VALID?pir_async:1'b0;
 station_picture_memory_status #(.SD_DATA_HALF(0),.PIR_HOLD_MS(20000),.LIGHT_POLARITY_VALID(LIGHT_POLARITY_VALID),.LIGHT_DARK_LEVEL(LIGHT_DARK_LEVEL)) station(
  .bus_clk(bus_clk),.pixel_clk(pixel_clk),.serial_clk(serial_clk),.memory_clk(memory_clk),.arst_n(logic_reset_n),
  .key_n(key_n),.keypad_valid(keypad_valid),.keypad_code(keypad_code),.keypad_long_valid(keypad_long_valid),.keypad_long_code(keypad_long_code),.pir_async(pir_input),.light_async(light_async),.video_cancel(1'b0),.photo_clear_fault(1'b0),.sd_retry_valid(1'b0),
  .sd_initialized(sd_initialized),.sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),
  .sdram_clk(sc),.sdram_ras_n(sr),.sdram_cas_n(ss),.sdram_we_n(sw),.sdram_addr(sa),.sdram_ba(sb),.sdram_dqm(sm),.sdram_dq(dq),
  .hdmi_data_p(hdmi_data_p),.hdmi_clock_p(hdmi_clock_p),.fault(fault),
  .music_selected(music_selected),.music_playing(music_playing),.emergency_latched(emergency_latched));
 // Integrated2Mx32 SDRAM macro, NOT external GPIO pin assignments.
 EG_PHY_SDRAM_2M_32 internal_sdram(.clk(sc),.ras_n(sr),.cas_n(ss),.we_n(sw),.addr(sa),.ba(sb),.dq(dq),
  .cs_n(1'b0),.cke(1'b1),.dm0(sm[0]),.dm1(sm[1]),.dm2(sm[2]),.dm3(sm[3]));
 // D6 LED now observes synchronized C11 PIR input (lit = input HIGH).
 // It is independent of SD, media selection, warmup and scene policy.
 reg pir_led_meta,pir_led_sync;
 always @(posedge bus_clk or negedge keypad_rst_n)begin
  if(!keypad_rst_n)begin pir_led_meta<=0;pir_led_sync<=0;end
  else begin pir_led_meta<=pir_input;pir_led_sync<=pir_led_meta;end
 end
 assign led_n=~{fault||emergency_latched,pir_led_sync,sd_initialized,logic_reset_n};
endmodule
