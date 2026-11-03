`timescale 1ns/1ps
// Audio part of station_media_read_frontend, with ONE external visual reader
// substituted for its old internal line DMA. All ports use the business clock.
// Reuses the original PCM prefetch/FIFO and audio-priority burst arbiter.
module station_shared_media_reader #(
 parameter integer PCM_AW=15,FIFO_AW=10,FIFO_DEPTH=1024,FIFO_PREFILL=128
)(
 input wire clk,rst_n,enabled,physical_tick,paused,
 input wire [PCM_AW:0] pcm_words_used,input wire [20:0] pcm_read_address,
 output wire pcm_read_advance,pcm_available,content_pop,sample_valid,
 output wire signed [15:0] sample_left,sample_right,output wire [FIFO_AW:0] fifo_level,
 input wire visual_rd_valid,output wire visual_rd_ready,input wire [20:0] visual_rd_address,
 output wire visual_data_valid,output wire [31:0] visual_data,output wire visual_last,
 input wire visual_idle,visual_fault,output wire line_idle,memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire fault
);
 wire av,ar,adv,al,pv,pr,pfault,afault;wire [20:0] aa;wire [31:0] ad;wire [15:0] pl,pp;
 wire unused_idle,unused_cv,unused_playing,unused_drained;wire [31:0] unused_underruns;
 assign fault=pfault||visual_fault||afault;
 assign line_idle=visual_idle;
 station_pcm_prefetch #(.PCM_AW(PCM_AW)) pcm_fetch(
  .clk(clk),.rst_n(rst_n),.enabled(enabled&&!fault),.words_used(pcm_words_used),
  .read_address(pcm_read_address),.read_advance(pcm_read_advance),
  .rd_valid(av),.rd_ready(ar),.rd_address(aa),.rd_data_valid(adv),.rd_data(ad),.rd_last(al),
  .pcm_valid(pv),.pcm_ready(pr),.pcm_left(pl),.pcm_right(pp),.idle(unused_idle),.fault(pfault));
 station_pcm_fifo #(.DEPTH(FIFO_DEPTH),.PREFILL(FIFO_PREFILL),.AW(FIFO_AW)) pcm_fifo(
  .clk(clk),.rst_n(rst_n),.flush(1'b0),.physical_tick(physical_tick),
  .in_valid(pv),.in_ready(pr),.in_left(pl),.in_right(pp),.eof(1'b0),.paused(paused||fault),
  .content_pop(content_pop),.content_available(pcm_available),.content_valid(unused_cv),
  .sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
  .level(fifo_level),.underruns(unused_underruns),.playing(unused_playing),.drained(unused_drained));
 station_memory_read_arbiter arbiter(
  .clk(clk),.rst_n(rst_n),.audio_valid(av),.audio_ready(ar),.audio_address(aa),
  .audio_data_valid(adv),.audio_data(ad),.audio_last(al),
  .video_valid(visual_rd_valid),.video_ready(visual_rd_ready),.video_address(visual_rd_address),
  .video_data_valid(visual_data_valid),.video_data(visual_data),.video_last(visual_last),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),
  .rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.idle(memory_quiet),.fault(afault));
endmodule
