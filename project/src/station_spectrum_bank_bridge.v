`timescale 1ns/1ps
// Pixel consumer reads within96clocks after a one-shot frame_tick, spaced>=96.
// Complete32-word packets only. snapshot_complete follows the last height word.
// Cancel invalidates at a frame boundary, without resetting live bank ownership.
module station_spectrum_bank_bridge #(parameter integer STORE_PIXEL_HEIGHT=0)(
 input wire src_clk,pixel_clk,arst_n,src_cancel,
 input wire height_valid,input wire [4:0] height_index,input wire [7:0] height,
 input wire snapshot_complete,output wire packet_ready,
 input wire frame_tick,input wire [4:0] read_index,
 output wire [7:0] read_height,output wire bank_valid,
 output reg [31:0] published_packets,dropped_packets,bad_packets
);
 wire srst;reset_sync release_src(.clk(src_clk),.arst_n(arst_n),.rst_n(srst));
 localparam IDLE=0,COLLECT=1,COMPLETE=2,SEND=3,ACK=4;
 reg [2:0] state;reg write_bank;reg [5:0] expected;
 reg cancel_previous,clear_pending,send_is_data;
 wire mailbox_ready;wire [1:0] pixel_bank;wire mailbox_valid;
 wire send_bank=srst&&state==SEND&&(!send_is_data||!src_cancel);
 station_frame_mailbox #(.WIDTH(2)) ownership(.src_clk(src_clk),.dst_clk(pixel_clk),.arst_n(arst_n),
  .src_data({send_is_data,write_bank}),.src_valid(send_bank),.src_ready(mailbox_ready),
  .dst_frame(frame_tick),.dst_data(pixel_bank),.dst_valid(mailbox_valid));
 (*ram_style="bram"*) reg [7:0] memory[0:63];reg [7:0] pixel_q;
 wire take_word=srst&&!src_cancel&&!clear_pending&&height_valid&&
  ((state==IDLE&&height_index==0)||(state==COLLECT&&{1'b0,height_index}==expected));
 wire [7:0] bounded_height=height>128?8'd128:height;
 wire [9:0] triple_height={2'b00,bounded_height}+{1'b0,bounded_height,1'b0};
 wire [7:0] stored_height=STORE_PIXEL_HEIGHT?{1'b0,triple_height[8:2]}:height;
 always @(posedge src_clk)if(take_word)memory[{write_bank,height_index}]<=stored_height;
 always @(posedge pixel_clk)pixel_q<=memory[{pixel_bank[0],read_index}];
 assign bank_valid=mailbox_valid&&pixel_bank[1];
 assign read_height=bank_valid?pixel_q:8'd0;
 assign packet_ready=srst&&state==IDLE&&!src_cancel&&!clear_pending;
 always @(posedge src_clk or negedge srst)begin
  if(!srst)begin
   state<=IDLE;write_bank<=0;expected<=0;published_packets<=0;dropped_packets<=0;bad_packets<=0;
   cancel_previous<=0;clear_pending<=0;send_is_data<=0;
  end else begin
   cancel_previous<=src_cancel;
   if(src_cancel&&!cancel_previous)clear_pending<=1;
   if(height_valid&&height_index==0&&(state==SEND||state==ACK||state==COMPLETE))dropped_packets<=dropped_packets+1'b1;
   case(state)
    IDLE:if(clear_pending)begin send_is_data<=0;state<=SEND;end
     else if(!src_cancel&&height_valid)begin
      if(height_index==0)begin expected<=1;state<=COLLECT;end
      else bad_packets<=bad_packets+1'b1;
     end
    COLLECT:if(src_cancel)begin state<=IDLE;expected<=0;end
     else if(snapshot_complete)begin bad_packets<=bad_packets+1'b1;state<=IDLE;end
     else if(height_valid)begin
      if({1'b0,height_index}!=expected)begin bad_packets<=bad_packets+1'b1;state<=IDLE;end
      else if(expected==31)begin expected<=32;state<=COMPLETE;end
      else expected<=expected+1'b1;
     end
    COMPLETE:if(src_cancel)state<=IDLE;
     else if(snapshot_complete)begin send_is_data<=1;state<=SEND;end
    SEND:if(send_is_data&&src_cancel)state<=IDLE;
     else if(mailbox_ready)begin
      if(send_is_data)begin published_packets<=published_packets+1'b1;write_bank<=!write_bank;end
      else clear_pending<=0;
      state<=ACK;
     end
    ACK:if(mailbox_ready)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
