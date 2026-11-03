`timescale 1ns/1ps
// Any raw lock loss asserts reset even if generated clocks have stopped.
// Release requires two ref-clock synchronizer stages, then stable qualification.
// Each consumer still synchronizes release in its own clock domain.
module station_clock_reset_guard #(parameter integer STABLE_CYCLES=32)(
 input wire refclk,reset_n,primary_locked,video_locked,
 output reg logic_reset_n
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam CW=bits_for(STABLE_CYCLES);
 wire clocks_good=reset_n&&primary_locked&&video_locked;
 reg [1:0] synchronized_good;reg [CW-1:0] stable_count;
 always @(posedge refclk or negedge clocks_good)begin
  if(!clocks_good)begin synchronized_good<=0;stable_count<=0;logic_reset_n<=0;end
  else begin
   synchronized_good<={synchronized_good[0],1'b1};
   if(synchronized_good[1]&&!logic_reset_n&&STABLE_CYCLES>0)begin
    if(stable_count==STABLE_CYCLES-1)logic_reset_n<=1;
    else stable_count<=stable_count+1'b1;
   end
  end
 end
endmodule
