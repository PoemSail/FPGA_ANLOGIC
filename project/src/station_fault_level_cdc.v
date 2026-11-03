`timescale 1ns/1ps
// Synchronize a source-domain sticky fault level into a destination clock.
// Source must hold the fault until recovery/reset; this is not a pulse catcher.
// Destination reset asserts asynchronously and must release synchronously.
// No combinational use of fault_async is permitted in destination decisions.
module station_fault_level_cdc(
 input wire dst_clk,dst_rst_n,fault_async,
 output wire fault_sync
);
 reg fault_meta,fault_sampled;
 always @(posedge dst_clk or negedge dst_rst_n)begin
  if(!dst_rst_n)begin fault_meta<=0;fault_sampled<=0;end
  else begin fault_meta<=fault_async;fault_sampled<=fault_meta;end
 end
 assign fault_sync=fault_sampled;
endmodule
