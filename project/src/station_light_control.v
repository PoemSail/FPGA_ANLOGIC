// Polarity is deliberately disabled until actual DO polarity is bound.
module station_light_control #(
    parameter integer SAMPLE_MS = 10,
    parameter integer STABLE_SAMPLES = 50,
    parameter integer POLARITY_VALID = 0,
    parameter integer DARK_LEVEL = 1
)(
    input wire clk, input wire rst_n, input wire tick_ms,
    input wire frame_commit, input wire light_async, input wire auto_enable,
    input wire signed [7:0] manual_brightness,
    output reg light_known, output reg dark,
    output wire auto_active,
    output reg signed [7:0] active_brightness
);
    reg light_meta, light_sync, candidate;
    reg [31:0] sample_count, stable_count;
    wire signed [7:0] bounded_manual = manual_brightness > 8'sd64 ? 8'sd64 :
        manual_brightness < -8'sd64 ? -8'sd64 : manual_brightness;
    assign auto_active = auto_enable && (POLARITY_VALID != 0);
    wire signed [7:0] target_brightness = auto_active ?
        // Night uses the same minimum brightness as the manual range.
        ((light_known && dark) ? -8'sd64 : 8'sd0) : bounded_manual;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin light_meta <= 0; light_sync <= 0; end
        else begin light_meta <= light_async; light_sync <= light_meta; end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate <= 0; sample_count <= 0; stable_count <= 0;
            light_known <= 0; dark <= 0; active_brightness <= 0;
        end else begin
            if (tick_ms) begin
                if (sample_count >= SAMPLE_MS-1) begin
                    sample_count <= 0;
                    if (light_sync != candidate) begin
                        candidate <= light_sync; stable_count <= 1;
                        if (STABLE_SAMPLES == 1) begin
                            light_known <= (POLARITY_VALID != 0);
                            dark <= (POLARITY_VALID != 0) && (light_sync == DARK_LEVEL);
                        end
                    end else if (stable_count < STABLE_SAMPLES) begin
                        stable_count <= stable_count + 1'b1;
                        if (stable_count >= STABLE_SAMPLES-1) begin
                            light_known <= (POLARITY_VALID != 0);
                            dark <= (POLARITY_VALID != 0) && (light_sync == DARK_LEVEL);
                        end
                    end
                end else sample_count <= sample_count + 1'b1;
            end
            if (frame_commit) begin
                if (!auto_active) active_brightness <= bounded_manual;
                else if (active_brightness < target_brightness)
                    active_brightness <= active_brightness + 1'b1;
                else if (active_brightness > target_brightness)
                    active_brightness <= active_brightness - 1'b1;
            end
        end
    end
endmodule
