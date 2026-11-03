`timescale 1ns/1ps
// Functional-interface resource candidate. Same complete picture-memory core;
// removes exported diagnostic counters, NOT media/control/FFT processing.
// Clocks and photo display pixels are still supplied externally. Not pin-bound.
module station_picture_compact(
 input wire bus_clk,pixel_clk,serial_clk,memory_clk,arst_n,input wire [2:0] key_n,input wire pir_async,light_async,video_cancel,
 input wire photo_request_valid,output wire photo_request_ready,input wire [1:0] photo_index,input wire photo_cancel,
 output wire photo_descriptor_valid,input wire photo_descriptor_ready,output wire photo_descriptor_error,
 output wire [7:0] photo_error,output wire [20:0] photo_base,output wire photo_slot,output wire [15:0] photo_generation,
 input wire photo_release_valid,photo_release_slot,input wire [15:0] photo_release_generation,input wire photo_clear_fault,
 input wire photo_pixel_valid,input wire [23:0] photo_rgb,
 input wire sd_retry_valid,output wire sd_retry_ready,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat,
 output wire sdram_clk,sdram_ras_n,sdram_cas_n,sdram_we_n,output wire [10:0] sdram_addr,output wire [1:0] sdram_ba,
 output wire [3:0] sdram_dqm,inout wire [31:0] sdram_dq,
 output wire [2:0] hdmi_data_p,output wire hdmi_clock_p,output wire fault
);
 wire core_fault,memory_fault,share_fault,pool_fault;
 assign fault=core_fault||memory_fault||share_fault||pool_fault;
 station_picture_memory_system core(.bus_clk(bus_clk),.pixel_clk(pixel_clk),.serial_clk(serial_clk),.memory_clk(memory_clk),.arst_n(arst_n),
  .key_n(key_n),.pir_async(pir_async),.light_async(light_async),.video_cancel(video_cancel),
  .photo_request_valid(photo_request_valid),.photo_request_ready(photo_request_ready),.photo_index(photo_index),.photo_cancel(photo_cancel),
  .photo_descriptor_valid(photo_descriptor_valid),.photo_descriptor_ready(photo_descriptor_ready),.photo_descriptor_error(photo_descriptor_error),
  .photo_error(photo_error),.photo_base(photo_base),.photo_slot(photo_slot),.photo_generation(photo_generation),
  .photo_release_valid(photo_release_valid),.photo_release_slot(photo_release_slot),.photo_release_generation(photo_release_generation),.photo_clear_fault(photo_clear_fault),
  .photo_pixel_valid(photo_pixel_valid),.photo_rgb(photo_rgb),.sd_retry_valid(sd_retry_valid),.sd_retry_ready(sd_retry_ready),
  .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),.sdram_clk(sdram_clk),.sdram_ras_n(sdram_ras_n),.sdram_cas_n(sdram_cas_n),.sdram_we_n(sdram_we_n),
  .sdram_addr(sdram_addr),.sdram_ba(sdram_ba),.sdram_dqm(sdram_dqm),.sdram_dq(sdram_dq),
  .hdmi_data_p(hdmi_data_p),.hdmi_clock_p(hdmi_clock_p),.fault(core_fault),.memory_fault(memory_fault),.share_fault(share_fault),.photo_pool_fault(pool_fault));
endmodule
