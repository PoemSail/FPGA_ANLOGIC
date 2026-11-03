`timescale 1ns/1ps
// Explicitly simulated station status; UI labels it as demonstration data.
module station_demo_status #(parameter integer CLOCKS_PER_MS=50000,MINUTE_MS=60000)(
 input wire clk,rst_n,frame_commit,output reg [9:0] scroll,
 output reg [7:0] arrival1,arrival2
);
 reg [31:0] ms_clocks;reg [15:0] ms_count;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin ms_clocks<=0;ms_count<=0;scroll<=0;arrival1<=3;arrival2<=5;end
  else begin
   if(frame_commit)scroll<=scroll+10'd2;
   if(ms_clocks==CLOCKS_PER_MS-1)begin
    ms_clocks<=0;
    if(ms_count==MINUTE_MS-1)begin
     ms_count<=0;arrival1<=arrival1==0?8'd3:arrival1-1'b1;arrival2<=arrival2==0?8'd5:arrival2-1'b1;
    end else ms_count<=ms_count+1'b1;
   end else ms_clocks<=ms_clocks+1'b1;
  end
 end
endmodule
