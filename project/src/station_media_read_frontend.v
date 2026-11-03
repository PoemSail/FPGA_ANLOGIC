`timescale 1ns/1ps
// R56 committed-memory read frontier. All ports synchronous to business clk.
// Reuses station_pcm_fifo and its shared external physical sample phase.
// line DMA must feed a separately reserved line bank; pixel CDC is external.
module station_media_read_frontend #(
 parameter integer PCM_AW=15,FIFO_AW=10,FIFO_DEPTH=1024,FIFO_PREFILL=128
)(
 input wire clk,rst_n,enabled,physical_tick,paused,
 input wire [PCM_AW:0] pcm_words_used,input wire [20:0] pcm_read_address,
 output wire pcm_read_advance,
 output wire pcm_available,content_pop,sample_valid,
 output wire signed [15:0] sample_left,sample_right,output wire [FIFO_AW:0] fifo_level,
 input wire publish,display_valid,display_slot,input wire [63:0] display_pts,
 input wire [15:0] display_width,display_height,
 input wire row_valid,output wire row_ready,input wire [8:0] row,input wire [63:0] row_pts,
 output wire word_valid,output wire [7:0] word_index,output wire [31:0] word_data,
 output wire line_done,line_rejected,output wire [8:0] line_row,output wire [63:0] line_pts,
 output wire line_idle,memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire fault
);
 wire av,ar,adv,al,vv,vr,vdv,vl,pv,pr,pfault,lfault,afault;
 wire [20:0] aa,va;wire [31:0] ad,vd;wire [15:0] pl,pp;
 wire unused_idle,unused_cv,unused_playing,unused_drained;wire [31:0] unused_underruns;
 assign fault=pfault||lfault||afault;
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
 station_rgb565_line_dma line_fetch(
  .clk(clk),.rst_n(rst_n),.enabled(enabled&&!fault),.publish(publish),
  .display_valid(display_valid),.display_slot(display_slot),.display_pts(display_pts),
  .display_width(display_width),.display_height(display_height),
  .row_valid(row_valid),.row_ready(row_ready),.row(row),.row_pts(row_pts),
  .rd_valid(vv),.rd_ready(vr),.rd_address(va),.rd_data_valid(vdv),.rd_data(vd),.rd_last(vl),
  .word_valid(word_valid),.word_index(word_index),.word_data(word_data),
  .line_done(line_done),.line_rejected(line_rejected),.line_row(line_row),.line_pts(line_pts),
  .idle(line_idle),.fault(lfault));
 station_memory_read_arbiter arbiter(
  .clk(clk),.rst_n(rst_n),.audio_valid(av),.audio_ready(ar),.audio_address(aa),
  .audio_data_valid(adv),.audio_data(ad),.audio_last(al),
  .video_valid(vv),.video_ready(vr),.video_address(va),
  .video_data_valid(vdv),.video_data(vd),.video_last(vl),
  .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_address(rd_address),
  .rd_data_valid(rd_data_valid),.rd_data(rd_data),.rd_last(rd_last),.idle(memory_quiet),.fault(afault));
endmodule
