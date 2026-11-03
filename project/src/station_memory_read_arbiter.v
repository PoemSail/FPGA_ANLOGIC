`timescale 1ns/1ps
// One outstanding, aligned BL8 read. Addresses are 32-bit WORD addresses.
// A response may first arrive on the clock AFTER bus acceptance; no response
// backpressure. Audio has priority only when IDLE: an offered request is held.
// All clients and memory must share reset/quiescence; reset cannot cancel RAM IO.
module station_memory_read_arbiter(
 input wire clk,rst_n,
 input wire audio_valid,output wire audio_ready,input wire [20:0] audio_address,
 output wire audio_data_valid,output wire [31:0] audio_data,output wire audio_last,
 input wire video_valid,output wire video_ready,input wire [20:0] video_address,
 output wire video_data_valid,output wire [31:0] video_data,output wire video_last,
 output wire rd_valid,input wire rd_ready,output reg [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire idle,output reg fault
);
 localparam IDLE=0,OFFER=1,WAIT_DATA=2;
 reg [1:0] state;reg owner_audio;reg [2:0] beat;
 assign idle=rst_n&&state==IDLE;
 assign rd_valid=rst_n&&state==OFFER&&!fault;
 assign audio_ready=rd_valid&&rd_ready&&owner_audio;
 assign video_ready=rd_valid&&rd_ready&&!owner_audio;
 assign audio_data_valid=rst_n&&state==WAIT_DATA&&rd_data_valid&&owner_audio;
 assign video_data_valid=rst_n&&state==WAIT_DATA&&rd_data_valid&&!owner_audio;
 assign audio_data=rd_data;assign video_data=rd_data;
 assign audio_last=rd_last;assign video_last=rd_last;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;owner_audio<=0;beat<=0;rd_address<=0;fault<=0;end
  else begin
   if(rd_data_valid)begin
    if(state!=WAIT_DATA)fault<=1;
    else begin
     if(rd_last!=(beat==7))fault<=1;
     if(beat==7)begin state<=IDLE;beat<=0;end else beat<=beat+1'b1;
    end
   end
   case(state)
    IDLE:if(!fault&&!rd_data_valid&&(audio_valid||video_valid))begin
     owner_audio<=audio_valid;rd_address<=audio_valid?audio_address:video_address;
     if((audio_valid?audio_address[2:0]:video_address[2:0])!=0)fault<=1;
     else state<=OFFER;
    end
    OFFER:if(rd_valid&&rd_ready)begin state<=WAIT_DATA;beat<=0;end
    WAIT_DATA:;
    default:begin fault<=1;state<=IDLE;end
   endcase
  end
 end
endmodule
