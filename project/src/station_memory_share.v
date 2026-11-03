`timescale 1ns/1ps
// Two clients share one ordered physical-write and aligned BL8 read backend.
// Owner tags exist for every accepted write until its response is consumed.
// Read returns have no backpressure; an accepted burst drains exactly8 beats.
// Common reset with backend/clients required. Fault stops NEW IO, not responses.
module station_memory_share #(parameter integer DEPTH=32)(
 input wire clk,rst_n,
 input wire [1:0] c_wr_valid,output wire [1:0] c_wr_ready,input wire [41:0] c_wr_address,input wire [63:0] c_wr_data,
 output wire [1:0] c_rsp_valid,input wire [1:0] c_rsp_ready,output wire [1:0] c_rsp_error,
 input wire [1:0] c_rd_valid,output wire [1:0] c_rd_ready,input wire [41:0] c_rd_address,
 output wire [1:0] c_data_valid,output wire [63:0] c_data,output wire [1:0] c_last,
 output wire wr_valid,input wire wr_ready,output wire [20:0] wr_address,output wire [31:0] wr_data,
 input wire rsp_valid,output wire rsp_ready,input wire rsp_error,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire data_valid,input wire [31:0] data,input wire last,
 output wire quiet,output reg fault
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam AW=bits_for(DEPTH),CW=bits_for(DEPTH+1);
 reg [DEPTH-1:0] tags;reg [AW-1:0] wp,rp;reg [CW-1:0] count;
 reg wlock,wowner,wturn,rlock,rowner,rturn,read_active,read_owner;reg [2:0] beat;
 wire head=tags[rp];wire wchosen=c_wr_valid[wturn]?wturn:!wturn;wire rchosen=c_rd_valid[rturn]?rturn:!rturn;
 assign wr_valid=rst_n&&!fault&&wlock&&c_wr_valid[wowner]&&count<DEPTH;
 assign wr_address=c_wr_address[wowner*21+:21];assign wr_data=c_wr_data[wowner*32+:32];
 assign c_wr_ready={2{wr_ready&&wr_valid}}&(wowner?2'b10:2'b01);
 assign rsp_ready=rst_n&&(count==0||c_rsp_ready[head]);
 assign c_rsp_valid={2{rst_n&&rsp_valid&&count!=0}}&(head?2'b10:2'b01);
 assign c_rsp_error={2{rsp_error||fault}};
 assign rd_valid=rst_n&&!fault&&!read_active&&rlock&&c_rd_valid[rowner]&&rd_address[2:0]==0;
 assign rd_address=c_rd_address[rowner*21+:21];
 assign c_rd_ready={2{rd_ready&&rd_valid}}&(rowner?2'b10:2'b01);
 assign c_data_valid={2{rst_n&&read_active&&data_valid}}&(read_owner?2'b10:2'b01);
 assign c_data={data,data};assign c_last={2{last}};
 wire put=wr_valid&&wr_ready,pop=rsp_valid&&rsp_ready&&count!=0,get=rd_valid&&rd_ready;
 assign quiet=rst_n&&count==0&&!wlock&&!rlock&&!read_active&&!(|c_wr_valid)&&!(|c_rd_valid)&&!rsp_valid&&!data_valid;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin tags<=0;wp<=0;rp<=0;count<=0;wlock<=0;wowner<=0;wturn<=0;rlock<=0;rowner<=0;rturn<=0;read_active<=0;read_owner<=0;beat<=0;fault<=0;end
  else begin
   if(!wlock&&!fault&&(|c_wr_valid))begin wlock<=1;wowner<=wchosen;end
   if(wlock&&(!c_wr_valid[wowner]||put))wlock<=0;
   if(put)begin tags[wp]<=wowner;wp<=wp==DEPTH-1?0:wp+1'b1;wturn<=!wowner;end
   if(pop)rp<=rp==DEPTH-1?0:rp+1'b1;
   case({put,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
   if(rsp_valid&&rsp_ready&&count==0)fault<=1;
   if(!rlock&&!read_active&&!fault&&(|c_rd_valid))begin rlock<=1;rowner<=rchosen;end
   if(rlock&&!c_rd_valid[rowner])rlock<=0;
   if(rlock&&c_rd_valid[rowner]&&rd_address[2:0]!=0)fault<=1;
   if(get)begin rlock<=0;read_active<=1;read_owner<=rowner;beat<=0;rturn<=!rowner;end
   if(data_valid)begin
    if(!read_active||last!=(beat==7))fault<=1;
    if(read_active)begin if(beat==7)begin read_active<=0;beat<=0;end else beat<=beat+1'b1;end
   end
  end
 end
endmodule
