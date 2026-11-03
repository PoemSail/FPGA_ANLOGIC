`timescale 1ns/1ps
// File-service byte interface; source must quiesce an old request before a new start.
// Playback pause preserves parser, FIFO and content position; physical tick is external.
module station_wav_player #(
 parameter integer DEPTH=2048,PREFILL=128,AW=11
)(input wire clk,rst_n,enable,play_enable,retry,physical_tick,
 output wire file_request,output wire file_cancel,
 input wire file_start_valid,output wire file_start_ready,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire sample_valid,output wire signed [15:0] sample_left,sample_right,
 output wire content_pop,output wire fault,output wire [3:0] error_code,
 output wire [AW:0] fifo_level,output wire [31:0] underruns,output reg [31:0] loops
);
 localparam RESET=0,IDLE=1,ACTIVE=2,DRAIN=3,FAULT=4;
 reg [2:0] state;wire decoder_rst_n=rst_n&&(state!=RESET);
 wire decoder_start_ready,done_valid,pcm_valid,pcm_ready,drained;
 wire [15:0] pcm_l,pcm_r;wire [3:0] decoder_error;
 wire start=state==IDLE&&enable&&file_start_valid;
 assign file_request=rst_n&&state==IDLE&&enable;
 assign file_start_ready=state==IDLE&&enable&&decoder_start_ready;
 assign file_cancel=rst_n&&retry&&(state==ACTIVE||state==DRAIN);
 assign fault=state==FAULT||decoder_error!=0;
 assign error_code=decoder_error;
 wav_pcm_decoder decoder(.clk(clk),.rst_n(decoder_rst_n),.start_valid(start),.start_ready(decoder_start_ready),
  .file_size(file_size),.byte_valid(byte_valid&&state==ACTIVE),.byte_ready(byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid),.source_done_ready(source_done_ready),.source_done_error(source_done_error),
  .pcm_valid(pcm_valid),.pcm_ready(pcm_ready),.pcm_left(pcm_l),.pcm_right(pcm_r),
  .done_valid(done_valid),.done_ready(1'b1),.error_code(decoder_error));
 station_pcm_fifo #(.DEPTH(DEPTH),.PREFILL(PREFILL),.AW(AW)) fifo(
  .clk(clk),.rst_n(rst_n),.flush(state==RESET||fault),.physical_tick(physical_tick),
  .in_valid(pcm_valid),.in_ready(pcm_ready),.in_left(pcm_l),.in_right(pcm_r),
  .eof(state==DRAIN),.paused(!play_enable||fault),.content_pop(content_pop),
  .content_available(),.content_valid(),.sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
  .level(fifo_level),.underruns(underruns),.playing(),.drained(drained));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=RESET;loops<=0;end
  else if(retry)state<=RESET;
  else case(state)
   RESET:state<=IDLE;
   IDLE:if(start&&decoder_start_ready)state<=ACTIVE;
   ACTIVE:if(done_valid)state<=decoder_error==0?DRAIN:FAULT;
   DRAIN:if(drained)begin loops<=loops+1'b1;state<=RESET;end
   FAULT:state<=FAULT;
   default:state<=RESET;
  endcase
 end
endmodule
