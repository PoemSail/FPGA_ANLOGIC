`timescale 1ns/1ps
// WAV player with explicit cancel/close ownership for global media recovery.
// source_quiet is the file context's actual quiescent level, not !byte_valid.
// Cancel masks NEW bytes, drains/accepts source closure, then resets decoder.
// Common reset remains legal only with the whole file/storage group reset.
module station_wav_player_quiescent #(
 parameter integer DEPTH=2048,PREFILL=128,AW=11
)(input wire clk,rst_n,enable,play_enable,retry,physical_tick,cancel,source_quiet,
 output wire file_request,file_cancel,
 input wire file_start_valid,output wire file_start_ready,input wire [31:0] file_size,
 input wire byte_valid,output wire byte_ready,input wire [7:0] byte_data,input wire byte_last,
 input wire source_done_valid,output wire source_done_ready,input wire source_done_error,
 output wire sample_valid,output wire signed [15:0] sample_left,sample_right,
 output wire content_pop,fault,output wire [3:0] error_code,
 output wire [AW:0] fifo_level,output wire [31:0] underruns,output reg [31:0] loops,
 output wire quiescent,prefilled
);
 localparam RESET=0,IDLE=1,ACTIVE=2,DRAIN=3,FAULT=4,ABORT=5,CANCELLED=6;
 reg [2:0] state;
 wire cancelling=cancel||retry||state==ABORT||state==CANCELLED;
 wire decoder_rst_n=rst_n&&state!=RESET&&state!=CANCELLED;
 wire decoder_start_ready,done_valid,pcm_valid,pcm_ready,drained,decoder_byte_ready,decoder_source_ready;
 wire [15:0] pcm_l,pcm_r;wire [3:0] decoder_error;
 wire start=state==IDLE&&enable&&!cancelling&&file_start_valid;
 assign file_request=rst_n&&state==IDLE&&enable&&!cancelling;
 assign file_start_ready=rst_n&&state==IDLE&&enable&&!cancelling&&decoder_start_ready;
 assign file_cancel=rst_n&&(cancel||retry||state==ABORT);
 assign byte_ready=rst_n&&state==ACTIVE&&!cancelling&&decoder_byte_ready;
 assign source_done_ready=rst_n&&(state==ABORT?1'b1:(state!=CANCELLED&&decoder_source_ready));
 assign fault=state==FAULT||decoder_error!=0;
 assign error_code=decoder_error;
 assign quiescent=rst_n&&(state==CANCELLED||(state==IDLE&&!file_request&&source_quiet));
 assign prefilled=rst_n&&!fault&&!cancelling&&((state==ACTIVE&&fifo_level>=PREFILL)||(state==DRAIN&&fifo_level!=0));
 wav_pcm_decoder decoder(.clk(clk),.rst_n(decoder_rst_n),.start_valid(start),.start_ready(decoder_start_ready),
  .file_size(file_size),.byte_valid(byte_valid&&state==ACTIVE&&!cancelling),.byte_ready(decoder_byte_ready),.byte_data(byte_data),.byte_last(byte_last),
  .source_done_valid(source_done_valid&&state!=ABORT&&state!=CANCELLED),.source_done_ready(decoder_source_ready),.source_done_error(source_done_error),
  .pcm_valid(pcm_valid),.pcm_ready(pcm_ready),.pcm_left(pcm_l),.pcm_right(pcm_r),
  .done_valid(done_valid),.done_ready(1'b1),.error_code(decoder_error));
 station_pcm_fifo #(.DEPTH(DEPTH),.PREFILL(PREFILL),.AW(AW)) fifo(
  .clk(clk),.rst_n(rst_n),.flush(state==RESET||state==CANCELLED||fault),.physical_tick(physical_tick),
  .in_valid(pcm_valid),.in_ready(pcm_ready),.in_left(pcm_l),.in_right(pcm_r),
  .eof(state==DRAIN),.paused(!play_enable||fault||cancelling),.content_pop(content_pop),
  .content_available(),.content_valid(),.sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
  .level(fifo_level),.underruns(underruns),.playing(),.drained(drained));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=RESET;loops<=0;end
  else if((cancel||retry)&&state!=ABORT&&state!=CANCELLED)state<=ABORT;
  else case(state)
   RESET:state<=IDLE;
   IDLE:if(start&&decoder_start_ready)state<=ACTIVE;
   ACTIVE:if(done_valid)state<=decoder_error==0?DRAIN:FAULT;
   DRAIN:if(drained)begin loops<=loops+1'b1;state<=RESET;end
   FAULT:state<=FAULT;
   ABORT:if(source_quiet||(source_done_valid&&source_done_ready))state<=CANCELLED;
   CANCELLED:if(!cancel&&!retry)state<=RESET;
   default:state<=ABORT;
  endcase
 end
endmodule
