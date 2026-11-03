`timescale 1ns/1ps
// Three-image request scheduler. Business-clock pulses only; frame_tick is
// the real60Hz commit event (default360 stable frames =6 seconds).
// One request/load at a time; changes during a load coalesce into desired_index.
// Result_accept means descriptor_valid&&descriptor_ready, not just load_done.
// Start timing only AFTER the matching slot/generation becomes the real front.
module station_photo_schedule #(parameter integer HOLD_FRAMES=360)(
 input wire clk,rst_n,photo_mode,paused,frame_tick,next_photo,previous_photo,
 input wire auto_start,auto_stop,retry,fatal_fault,
 output wire request_valid,input wire request_ready,output reg [1:0] request_index,
 input wire result_accept,result_error,result_slot,input wire [15:0] result_generation,
 input wire front_valid,front_slot,input wire [15:0] front_generation,
 output reg [1:0] desired_index,current_index,output reg current_known,auto_running,
 output wire busy,load_error,output reg protocol_fault
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 function [1:0] next_index;input [1:0] n;begin next_index=n==2?0:n+1'b1;end endfunction
 function [1:0] prev_index;input [1:0] n;begin prev_index=n==0?2:n-1'b1;end endfunction
 localparam IDLE=0,OFFER=1,RESULT=2,FRONT=3,ERROR=4;
 localparam CW=bits_for(HOLD_FRAMES+1);
 reg [2:0] state;reg [CW-1:0] stable_frames;reg expected_slot;reg [15:0] expected_generation;
 wire manual=photo_mode&&(next_photo||previous_photo);
 wire stopped=fatal_fault||protocol_fault;
 assign request_valid=rst_n&&state==OFFER&&!stopped;
 assign busy=rst_n&&(state==OFFER||state==RESULT||state==FRONT);
 assign load_error=rst_n&&state==ERROR;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;stable_frames<=0;expected_slot<=0;expected_generation<=0;request_index<=0;
   desired_index<=0;current_index<=0;current_known<=0;auto_running<=1;protocol_fault<=HOLD_FRAMES<1;
  end else begin
   if(result_accept&&state!=RESULT)protocol_fault<=1;
   if(!stopped)begin
    case(state)
     IDLE:begin
      if(photo_mode&&!manual&&(!current_known||desired_index!=current_index))begin request_index<=desired_index;state<=OFFER;end
      else if(photo_mode&&!paused&&auto_running&&current_known&&desired_index==current_index&&frame_tick&&!manual&&!auto_start&&!auto_stop)begin
       if(stable_frames==HOLD_FRAMES-1)begin desired_index<=next_index(current_index);stable_frames<=0;end
       else stable_frames<=stable_frames+1'b1;
      end
     end
     OFFER:if(request_valid&&request_ready)state<=RESULT;
     RESULT:if(result_accept)begin
      if(result_error)state<=ERROR;
      else if(result_generation==0)protocol_fault<=1;
      else begin expected_slot<=result_slot;expected_generation<=result_generation;state<=FRONT;end
     end
     FRONT:if(front_valid&&front_slot==expected_slot&&front_generation==expected_generation)begin
      current_known<=1;current_index<=request_index;stable_frames<=0;state<=IDLE;
     end
     ERROR:if(retry||manual)begin state<=IDLE;stable_frames<=0;end
     default:protocol_fault<=1;
    endcase
    if(auto_start)begin auto_running<=1;stable_frames<=0;end
    if(auto_stop)begin auto_running<=0;stable_frames<=0;end
    // Next wins simultaneous navigation. Keep the offered index stable and
    // finish its transaction; issue only the final desired index afterwards.
    if(manual)begin
     desired_index<=next_photo?next_index(desired_index):prev_index(desired_index);
     auto_running<=0;stable_frames<=0;
    end
   end
  end
 end
endmodule
