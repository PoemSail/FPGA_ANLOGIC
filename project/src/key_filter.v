`timescale 1ns/1ps
// 低有效按键先两级同步，再按各键独立计数消抖。
// FILTER_CYCLES >= 1；默认25MHz下500000周期=20ms。
// key_down高表示稳定按下；press/release各为一个clk周期，无自动连发。
// 复位期间视为全部松开；复位后一直按住的键会产生一次press。
module key_filter #(
    parameter integer KEY_COUNT = 3,
    parameter integer FILTER_CYCLES = 500000
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [KEY_COUNT-1:0]  key_n,
    output reg  [KEY_COUNT-1:0]  key_down,
    output reg  [KEY_COUNT-1:0]  key_press,
    output reg  [KEY_COUNT-1:0]  key_release
);
    function integer bits_for;
        input integer value;
        integer work;
        begin
            work = value - 1;
            bits_for = 0;
            while (work > 0) begin
                bits_for = bits_for + 1;
                work = work >> 1;
            end
            if (bits_for < 1) bits_for = 1;
        end
    endfunction
    localparam integer COUNT_W = bits_for(FILTER_CYCLES);
    localparam [COUNT_W-1:0] COUNT_LAST = FILTER_CYCLES - 1;
    reg [KEY_COUNT-1:0] key_meta_n;
    reg [KEY_COUNT-1:0] key_sync_n;
    reg [COUNT_W-1:0] count [0:KEY_COUNT-1];
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_meta_n <= {KEY_COUNT{1'b1}};
            key_sync_n <= {KEY_COUNT{1'b1}};
        end else begin
            key_meta_n <= key_n;
            key_sync_n <= key_meta_n;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_down <= {KEY_COUNT{1'b0}};
            key_press <= {KEY_COUNT{1'b0}};
            key_release <= {KEY_COUNT{1'b0}};
            for (k = 0; k < KEY_COUNT; k = k + 1)
                count[k] <= {COUNT_W{1'b0}};
        end else begin
            key_press <= {KEY_COUNT{1'b0}};
            key_release <= {KEY_COUNT{1'b0}};
            for (k = 0; k < KEY_COUNT; k = k + 1) begin
                if (key_sync_n[k] == ~key_down[k]) begin
                    count[k] <= {COUNT_W{1'b0}};
                end else if (count[k] == COUNT_LAST) begin
                    count[k] <= {COUNT_W{1'b0}};
                    key_down[k] <= ~key_sync_n[k];
                    key_press[k] <= ~key_sync_n[k];
                    key_release[k] <= key_sync_n[k];
                end else begin
                    count[k] <= count[k] + 1'b1;
                end
            end
        end
    end
endmodule
