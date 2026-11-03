`timescale 1ns/1ps
// 低有效复位：异步拉低，在本时钟域连续两个上升沿后同步释放。
// 每个独立时钟域各实例化一份；物理同步器约束在板级实现阶段核验。
module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire rst_n
);
    reg [1:0] release_ff;
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            release_ff <= 2'b00;
        else
            release_ff <= {release_ff[0], 1'b1};
    end
    assign rst_n = release_ff[1];
endmodule
