// SNAPSHOT_INPUT=0 requires raw_levels stable until ready returns.
`timescale 1ns/1ps
// Pixel-domain state, frame_tick only in blank. 32 bands update in96clocks.
// Synchronous pixel read has one-clock latency. No frame buffer and no new CDC.
// All frame input levels are atomically sampled. Initial32clocks clear state.
module station_spectrum_panel_state #(parameter integer SNAPSHOT_INPUT=1,STREAM_INPUT=0,PIXEL_HEIGHT_INPUT=0)(
 input wire clk,rst_n,frame_tick,input wire [255:0] raw_levels,
 input wire [7:0] stream_level,output wire [4:0] stream_address,
 input wire [4:0] read_bin,output wire [6:0] pixel_bar,pixel_peak,
 output wire ready,output reg busy,output reg [31:0] frames,busy_frame_ticks
);
 (*ram_style="bram"*) reg [17:0] state_memory[0:31];
 reg [17:0] update_q,pixel_q;reg [4:0] cursor;
 reg [2:0] state;reg initialized;reg pixel_initialized;reg [255:0] sampled;
 // State layout: hold[17:14], peak[13:7], bar[6:0], all in pixels.
 wire [255:0] coherent_levels=SNAPSHOT_INPUT?sampled:raw_levels;
 wire [7:0] raw=STREAM_INPUT?stream_level:coherent_levels[cursor*8+:8];
 assign stream_address=cursor;
 wire [7:0] bounded=raw>128?8'd128:raw;
 wire [9:0] three={2'b00,bounded}+{1'b0,bounded,1'b0};
 // Matched source bridge provides bounded0..96 pixel heights.
 wire [6:0] target=(STREAM_INPUT&&PIXEL_HEIGHT_INPUT)?raw[6:0]:three[8:2];
 wire [6:0] old_bar=update_q[6:0],old_peak=update_q[13:7];
 wire [3:0] old_hold=update_q[17:14];
 wire [6:0] falling_bar=old_bar>3?old_bar-7'd3:7'd0;
 wire [6:0] falling_peak=old_peak>2?old_peak-7'd2:7'd0;
 // FETCH -> COMPUTE -> WRITE: arithmetic is registered before RAM write muxes.
 reg [6:0] cached_target,cached_falling_bar,cached_falling_peak;
 reg [3:0] cached_decrement_hold;
 reg cached_ge_bar,cached_ge_peak,cached_has_hold;
 wire [6:0] next_bar=cached_ge_bar?cached_target:
  cached_target>cached_falling_bar?cached_target:cached_falling_bar;
 // update_q remains on this cursor through WRITE; old_peak needs no arithmetic.
 wire [6:0] next_peak=cached_ge_peak?cached_target:cached_has_hold?old_peak:
  cached_target>cached_falling_peak?cached_target:cached_falling_peak;
 wire [3:0] next_hold=cached_ge_peak?(cached_target==0?4'd0:4'd12):
  cached_has_hold?cached_decrement_hold:4'd0;
 assign ready=initialized&&!busy;
 assign pixel_bar=pixel_initialized?pixel_q[6:0]:7'd0;
 assign pixel_peak=pixel_initialized?pixel_q[13:7]:7'd0;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)pixel_initialized<=0;else pixel_initialized<=initialized;
 end
 // One read-only pixel port and one shared update read/write port.
 // Extra update reads during writes are unused; no output depends on collisions.
 wire memory_write=rst_n&&(state==0||state==4);
 wire [17:0] memory_write_data=state==0?18'd0:{next_hold,next_peak,next_bar};
 always @(posedge clk)pixel_q<=state_memory[read_bin];
 always @(posedge clk)begin
  if(memory_write)state_memory[cursor]<=memory_write_data;
  update_q<=state_memory[cursor];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=0;cursor<=0;initialized<=0;sampled<=0;busy<=1;frames<=0;busy_frame_ticks<=0;
   cached_target<=0;cached_falling_bar<=0;cached_falling_peak<=0;
   cached_decrement_hold<=0;cached_ge_bar<=0;cached_ge_peak<=0;cached_has_hold<=0;
  end
  else begin
   if(frame_tick&&!ready)busy_frame_ticks<=busy_frame_ticks+1'b1;
   case(state)
    0:if(cursor==31)begin initialized<=1;busy<=0;state<=1;cursor<=0;end else cursor<=cursor+1'b1;
    1:if(frame_tick)begin sampled<=raw_levels;cursor<=0;state<=2;busy<=1;end
    2:state<=3;
    3:begin
     cached_target<=target;cached_falling_bar<=falling_bar;cached_falling_peak<=falling_peak;
     cached_decrement_hold<=old_hold-1'b1;
     cached_ge_bar<=target>=old_bar;cached_ge_peak<=target>=old_peak;
     cached_has_hold<=old_hold!=0;state<=4;
    end
    4:if(cursor==31)begin state<=1;busy<=0;frames<=frames+1'b1;end else begin cursor<=cursor+1'b1;state<=2;end
   endcase
  end
 end
endmodule
