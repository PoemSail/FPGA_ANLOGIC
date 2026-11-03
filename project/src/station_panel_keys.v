`timescale 1ns/1ps
// Reuses key_filter. Release actions, no repeat; alarm chord suppresses all singles.
module station_panel_keys #(
 parameter integer FILTER_CYCLES=1000000,
 parameter integer LONG_CYCLES=50000000,
 parameter integer CLEAR_CYCLES=100000000
)(input wire clk,rst_n,input wire [2:0] key_n,input wire emergency_latched,
 output reg [2:0] short_press,long_press,output reg emergency_set,emergency_clear);
 wire [2:0] down,pressed,released;
 reg [31:0] held[0:2];reg [2:0] used;
 reg chord_seen,clear_armed,clear_used;reg [31:0] clear_count;integer i;
 wire both=down[0]&&down[1];
 key_filter #(.KEY_COUNT(3),.FILTER_CYCLES(FILTER_CYCLES)) filter(
  .clk(clk),.rst_n(rst_n),.key_n(key_n),.key_down(down),.key_press(pressed),.key_release(released));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   short_press<=0;long_press<=0;emergency_set<=0;emergency_clear<=0;
   used<=0;chord_seen<=0;clear_armed<=0;clear_used<=0;clear_count<=0;
   for(i=0;i<3;i=i+1)held[i]<=0;
  end else begin
   short_press<=0;long_press<=0;emergency_set<=0;emergency_clear<=0;
   if(!emergency_latched)begin clear_armed<=0;clear_count<=0;clear_used<=0;end
   else begin
    if(down==0)begin clear_armed<=1;clear_used<=0;end
    if(both&&clear_armed&&!clear_used)begin
     if(clear_count>=CLEAR_CYCLES-1)begin emergency_clear<=1;clear_used<=1;clear_count<=0;end
     else clear_count<=clear_count+1'b1;
    end else clear_count<=0;
   end
   if(both&&!chord_seen)begin
    chord_seen<=1;
    if(!emergency_latched)emergency_set<=1;
   end
   if(down==0&&released==0)chord_seen<=0;
   for(i=0;i<3;i=i+1)begin
    if(!down[i])begin held[i]<=0;if(!released[i])used[i]<=0;end
    else if(!used[i]&&!both&&!chord_seen&&!emergency_latched)begin
     if(held[i]>=LONG_CYCLES-1)begin used[i]<=1;long_press[i]<=1;end
     else held[i]<=held[i]+1'b1;
    end
    if(released[i]&&!used[i]&&!both&&!chord_seen&&!emergency_latched)short_press[i]<=1;
   end
  end
 end
endmodule
