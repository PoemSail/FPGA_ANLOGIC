// OSD-stack derivative; predecessor unchanged.
// Transition-stack derivative; verified predecessor preserved.
`timescale 1ns/1ps
// Full logic stack with physical-key first/next/previous/auto/retry photo
// scheduling. External clocks and physical timing closure are still required.
module station_picture_osd(
 input wire bus_clk,pixel_clk,serial_clk,memory_clk,arst_n,
 input wire [2:0] key_n,input wire pir_async,light_async,video_cancel,
 input wire photo_clear_fault,sd_retry_valid,output wire sd_retry_ready,
 output wire photo_auto_running,photo_load_error,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat,
 output wire sdram_clk,sdram_ras_n,sdram_cas_n,sdram_we_n,
 output wire [10:0] sdram_addr,output wire [1:0] sdram_ba,output wire [3:0] sdram_dqm,inout wire [31:0] sdram_dq,
 output wire [2:0] hdmi_data_p,output wire hdmi_clock_p,output wire fault
);
 wire core_fault,memory_fault,share_fault,pool_fault;
 assign fault=core_fault||memory_fault||share_fault||pool_fault;
 station_picture_memory_osd core(.bus_clk(bus_clk),.pixel_clk(pixel_clk),.serial_clk(serial_clk),.memory_clk(memory_clk),.arst_n(arst_n),
  .key_n(key_n),.pir_async(pir_async),.light_async(light_async),.video_cancel(video_cancel),
  .photo_clear_fault(photo_clear_fault),.photo_auto_running(photo_auto_running),.photo_load_error(photo_load_error),
  .sd_retry_valid(sd_retry_valid),.sd_retry_ready(sd_retry_ready),.sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),
  .sdram_clk(sdram_clk),.sdram_ras_n(sdram_ras_n),.sdram_cas_n(sdram_cas_n),.sdram_we_n(sdram_we_n),
  .sdram_addr(sdram_addr),.sdram_ba(sdram_ba),.sdram_dqm(sdram_dqm),.sdram_dq(sdram_dq),
  .hdmi_data_p(hdmi_data_p),.hdmi_clock_p(hdmi_clock_p),.fault(core_fault),.memory_fault(memory_fault),.share_fault(share_fault),.photo_pool_fault(pool_fault));
endmodule
