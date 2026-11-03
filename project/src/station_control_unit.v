// Abstract 50MHz-domain control unit. No board pins or HDMI CDC are implied.
module station_control_unit #(
    parameter integer CLOCKS_PER_MS = 50000,
    parameter integer ENABLE_MANUAL_HOLD = 0,
    parameter integer PIR_WARMUP_MS = 60000,
    parameter integer PIR_HIGH_MS = 50,
    parameter integer PIR_LOW_MS = 100,
    parameter integer PIR_HOLD_MS = 20000,
    parameter integer MANUAL_SERVICE_MS = 20000,
    parameter integer LIGHT_SAMPLE_MS = 10,
    parameter integer LIGHT_STABLE_SAMPLES = 50,
    parameter integer LIGHT_POLARITY_VALID = 0,
    parameter integer LIGHT_DARK_LEVEL = 1
)(
    input wire clk, input wire reset_n_async,
    input wire pir_async, input wire light_async,
    input wire frame_commit,
    input wire manual_service_pulse, input wire service_hold,
    input wire emergency_set, input wire emergency_clear,
    input wire media_fault, input wire user_playing, input wire auto_brightness_enable,
    input wire signed [7:0] manual_brightness,
    output wire pir_warmup_done, output wire pir_motion, output wire pir_service,
    output wire light_known, output wire dark, output wire auto_brightness_active,
    output wire signed [7:0] active_brightness,
    output reg emergency_latched,
    output reg [1:0] active_scene,
    output wire [1:0] requested_scene,
    output wire content_play_enable, output wire alert_enable
);
    reg [1:0] reset_release;
    wire rst_n = reset_release[1];
    reg [31:0] ms_counter, manual_remaining;
    reg tick_ms;
    wire manual_active = (manual_remaining != 0) || manual_service_pulse;
    // Simultaneous set+clear always preserves the alarm.
    wire emergency_effective = emergency_set || (emergency_latched && !emergency_clear);
    wire manual_hold = (ENABLE_MANUAL_HOLD != 0) && service_hold;
    assign requested_scene = emergency_effective ? 2'd3 : media_fault ? 2'd2 :
        (pir_service || manual_active || manual_hold) ? 2'd1 : 2'd0;
    assign content_play_enable = user_playing && requested_scene == 0 && active_scene == 0;
    assign alert_enable = emergency_effective || active_scene == 3;
    always @(posedge clk or negedge reset_n_async) begin
        if (!reset_n_async) reset_release <= 0;
        else reset_release <= {reset_release[0],1'b1};
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter <= 0; tick_ms <= 0; manual_remaining <= 0;
            emergency_latched <= 0; active_scene <= 0;
        end else begin
            tick_ms <= 0;
            if (ms_counter >= CLOCKS_PER_MS-1) begin ms_counter <= 0; tick_ms <= 1; end
            else ms_counter <= ms_counter + 1'b1;
            if (manual_service_pulse) manual_remaining <= MANUAL_SERVICE_MS;
            else if (tick_ms && manual_remaining != 0) manual_remaining <= manual_remaining - 1'b1;
            if (emergency_set) emergency_latched <= 1;
            else if (emergency_clear) emergency_latched <= 0;
            if (frame_commit) active_scene <= requested_scene;
        end
    end
    station_pir_conditioner #(
        .WARMUP_MS(PIR_WARMUP_MS),.HIGH_MS(PIR_HIGH_MS),.LOW_MS(PIR_LOW_MS),.HOLD_MS(PIR_HOLD_MS)
    ) pir(.clk(clk),.rst_n(rst_n),.tick_ms(tick_ms),.pir_async(pir_async),
          .warmup_done(pir_warmup_done),.motion_level(pir_motion),.service_request(pir_service));
    station_light_control #(
        .SAMPLE_MS(LIGHT_SAMPLE_MS),.STABLE_SAMPLES(LIGHT_STABLE_SAMPLES),
        .POLARITY_VALID(LIGHT_POLARITY_VALID),.DARK_LEVEL(LIGHT_DARK_LEVEL)
    ) light(.clk(clk),.rst_n(rst_n),.tick_ms(tick_ms),.frame_commit(frame_commit),
        .light_async(light_async),.auto_enable(auto_brightness_enable),.manual_brightness(manual_brightness),
        .light_known(light_known),.dark(dark),.auto_active(auto_brightness_active),.active_brightness(active_brightness));
endmodule
