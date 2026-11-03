`timescale 1ns/1ps
// One clock domain; use the SAME physical48kHz tick as the playback FIFO.
// Every ready/valid request is accepted, including busy retriggers. Old tone
// fades out before fresh phase/attack; user volume is current at every tick.
// Full amplitude15360 at volume15;64-sample attack/release, default2s hold.
// Standalone producer, not yet integrated with the production player.
module notification_tone_r21 #(
 parameter integer DURATION_SAMPLES=96000
)(
 input wire clk,rst_n,sample_tick,
 input wire request_valid,output wire request_ready,
 input wire [3:0] volume,
 output wire active,
 output reg sample_valid,sample_active,
 output reg signed [15:0] sample
);
 localparam COUNT_BITS=DURATION_SAMPLES<2 ? 1 : $clog2(DURATION_SAMPLES+1);
 reg busy,restart_pending;
 reg [COUNT_BITS-1:0] remaining;
 reg [31:0] phase;
 reg [10:0] envelope;
 wire accept=request_valid&&request_ready;
 assign request_ready=rst_n;
 assign active=busy;
 wire signed [16:0] ramp=phase[31] ?
  (17'sd32767-$signed({1'b0,phase[30:15]})) :
  ($signed({1'b0,phase[30:15]})-17'sd32768);
 // Envelope is always a multiple of16: reset0, attack/release steps16.
 // Associate the small unsigned gains first; round only at the final shift.
 // ramp*envelope*volume>>15 == ramp*(envelope/16*volume)>>11 exactly.
 wire [10:0] envelope_volume=envelope[10:4]*volume;
 wire signed [28:0] gained=ramp*$signed({1'b0,envelope_volume});
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   busy<=0;restart_pending<=0;remaining<=0;phase<=0;envelope<=0;
   sample_valid<=0;sample_active<=0;sample<=0;
  end else begin
   sample_valid<=sample_tick;
   if(sample_tick)begin
    sample_active<=busy;
    sample<=busy ? (gained>>>11) : 16'sd0;
    if(busy)begin
     phase<=phase+32'd78741067;
     if(remaining!=0)begin
      remaining<=remaining-1'b1;
      if(envelope<1024)envelope<=envelope+11'd16;
     end else if(envelope>16)envelope<=envelope-11'd16;
     else begin
      envelope<=0;
      if(restart_pending)begin phase<=0;remaining<=DURATION_SAMPLES;restart_pending<=0;busy<=1;end
      else busy<=0;
     end
    end
   end
   // Busy retrigger first fades the old phase to zero. Requests coalesce
   // during this bounded release; background duck remains active throughout.
   if(accept)begin
    busy<=1;
    if(!busy||envelope==0||(sample_tick&&remaining==0&&envelope<=16))begin
     remaining<=DURATION_SAMPLES;phase<=0;envelope<=0;restart_pending<=0;
    end else begin remaining<=0;restart_pending<=1;end
   end
  end
 end
endmodule
