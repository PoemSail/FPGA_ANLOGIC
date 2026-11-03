`timescale 1ns/1ps
// Business-clock ownership tokens: FREE -> RESERVED -> PUBLISHED -> FREE.
// A release is a one-cycle event and must carry the published generation.
// Bad/stale release or completion is ignored and sets observable sticky fault.
module station_photo_allocator #(
 parameter [20:0] BASE0=21'h40000,BASE1=21'h52000
)(
 input wire clk,rst_n,clear_fault,
 input wire reserve_valid,output wire reserve_ready,output wire reserve_slot,
 output wire [15:0] reserve_generation,output wire [20:0] reserve_base,
 input wire complete_valid,input wire complete_slot,input wire [15:0] complete_generation,input wire complete_error,
 input wire release_valid,input wire release_slot,input wire [15:0] release_generation,
 output wire [1:0] busy,published,output reg fault
);
 localparam FREE=0,RESERVED=1,PUBLISHED=2;
 reg [1:0] state0,state1;reg [15:0] generation0,generation1;
 assign reserve_ready=rst_n&&(state0==FREE||state1==FREE);
 assign reserve_slot=state0!=FREE;
 assign reserve_generation=(reserve_slot?generation1:generation0)+16'd1;
 assign reserve_base=reserve_slot?BASE1:BASE0;
 assign busy={state1!=FREE,state0!=FREE};assign published={state1==PUBLISHED,state0==PUBLISHED};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state0<=FREE;state1<=FREE;generation0<=0;generation1<=0;fault<=0;end
  else begin
   if(clear_fault)fault<=0;
   if(release_valid)begin
    if(!release_slot&&state0==PUBLISHED&&release_generation==generation0)state0<=FREE;
    else if(release_slot&&state1==PUBLISHED&&release_generation==generation1)state1<=FREE;
    else fault<=1;
   end
   if(complete_valid)begin
    if(!complete_slot&&state0==RESERVED&&complete_generation==generation0)state0<=complete_error?FREE:PUBLISHED;
    else if(complete_slot&&state1==RESERVED&&complete_generation==generation1)state1<=complete_error?FREE:PUBLISHED;
    else fault<=1;
   end
   if(reserve_valid&&reserve_ready)begin
    if(reserve_slot)begin state1<=RESERVED;generation1<=generation1+1'b1;end
    else begin state0<=RESERVED;generation0<=generation0+1'b1;end
   end
  end
 end
endmodule
