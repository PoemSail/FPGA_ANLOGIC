`timescale 1ns/1ps
// Committed stereo ring -> eight-word staging -> existing station_pcm_fifo.
// Reserve ring words until downstream ACCEPTANCE, not memory read completion.
// Ring origin/capacity and record size (2000) are multiples of eight words.
// Memory responses are BL8 with no backpressure; last only on beat seven.
module station_pcm_prefetch #(parameter integer PCM_AW=15)(
 input wire clk,rst_n,enabled,input wire [PCM_AW:0] words_used,
 input wire [20:0] read_address,output wire read_advance,
 output wire rd_valid,input wire rd_ready,output reg [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire pcm_valid,input wire pcm_ready,output wire [15:0] pcm_left,pcm_right,
 output wire idle,output reg fault
);
 localparam EMPTY=0,OFFER=1,FILL=2,DRAIN=3;
 reg [1:0] state;reg [2:0] beat,out_index;reg [31:0] stash[0:7];
 assign idle=rst_n&&state==EMPTY;
 assign rd_valid=rst_n&&state==OFFER&&!fault;
 assign pcm_valid=rst_n&&state==DRAIN&&!fault;
 assign pcm_left=stash[out_index][15:0];assign pcm_right=stash[out_index][31:16];
 assign read_advance=pcm_valid&&pcm_ready;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=EMPTY;beat<=0;out_index<=0;rd_address<=0;fault<=0;end
  else begin
   if(rd_data_valid&&state!=FILL)fault<=1;
   case(state)
    EMPTY:if(enabled&&!fault&&!rd_data_valid&&words_used>=8)begin
     if(read_address[2:0]!=0)fault<=1;
     else begin rd_address<=read_address;state<=OFFER;end
    end
    OFFER:if(rd_valid&&rd_ready)begin state<=FILL;beat<=0;end
    FILL:if(rd_data_valid)begin
     stash[beat]<=rd_data;
     if(rd_last!=(beat==7))fault<=1;
     if(beat==7)begin state<=DRAIN;out_index<=0;end else beat<=beat+1'b1;
    end
    DRAIN:if(read_advance)begin
     if(words_used==0)fault<=1;
     if(out_index==7)state<=EMPTY;else out_index<=out_index+1'b1;
    end
    default:begin fault<=1;state<=EMPTY;end
   endcase
  end
 end
endmodule
