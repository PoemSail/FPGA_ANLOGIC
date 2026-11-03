// Alternative cache; default strict branch restores parent byte-exactly.
`timescale 1ns/1ps
// Shared single-sector backend, independent CRC-quarantined client caches.
// Request accepted on c_request && c_ready; exactly one512-byte sector or
// error-only completion per client. Hold payload/last/done while stalled.
// A stalled client never retains the physical backend after sector completion.
// Round robin between pending clients; no multi-sector burst ownership.
// Common reset discards all transactions and must also reset the backend.
module station_sector_cache #(parameter integer CLIENTS=2,NATIVE_STREAM=0)(
 input wire clk,rst_n,backend_failed,
 input wire [CLIENTS-1:0] c_request,output wire [CLIENTS-1:0] c_ready,
 input wire [CLIENTS*32-1:0] c_lba,
 output wire [CLIENTS-1:0] c_data_valid,input wire [CLIENTS-1:0] c_data_ready,
 output wire [CLIENTS*8-1:0] c_data,output wire [CLIENTS-1:0] c_last,
 output wire [CLIENTS-1:0] c_done_valid,input wire [CLIENTS-1:0] c_done_ready,
 output wire [CLIENTS-1:0] c_error,output wire [CLIENTS-1:0] c_busy,
 output wire read_valid,input wire read_ready,output wire [31:0] read_lba,
 input wire data_valid,output wire data_ready,input wire [7:0] data,input wire data_last,
 input wire done_valid,output wire done_ready,input wire done_error,
 output reg [31:0] sectors_ok,sectors_bad
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam OW=bits_for(CLIENTS),IDLE=0,SEND=1,RECEIVE=2;
 localparam FREE=0,WAITING=1,FILLING=2,FETCH=3,STREAM=4,RESULT=5,WAIT_FINISH=6;
 reg [1:0] state;reg [OW-1:0] owner,round_robin;
 wire [CLIENTS-1:0] waiting;wire [31:0] lbas[0:CLIENTS-1];
 reg chosen;reg [OW-1:0] choice;integer k,index;
 always @*begin
  chosen=0;choice=0;
  for(k=0;k<CLIENTS;k=k+1)begin
   index=round_robin+k;if(index>=CLIENTS)index=index-CLIENTS;
   if(!chosen&&waiting[index])begin chosen=1;choice=index;end
  end
 end
 reg [9:0] count;reg bad;
 assign read_valid=rst_n&&state==SEND&&!backend_failed;
 assign read_lba=lbas[owner];
 assign data_ready=rst_n&&state==RECEIVE;
 assign done_ready=rst_n&&state==RECEIVE;
 wire launch=read_valid&&read_ready;
 wire byte_accept=data_valid&&data_ready;
 wire framing_bad=byte_accept&&(count>=512||data_last!=(count==511));
 wire [10:0] count_after={1'b0,count}+byte_accept;
 wire complete=(done_valid&&done_ready)||(state==SEND&&backend_failed);
 wire complete_error=state==SEND||done_error||bad||framing_bad||count_after!=512;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;owner<=0;round_robin<=0;count<=0;bad<=0;sectors_ok<=0;sectors_bad<=0;end
  else begin
   case(state)
    IDLE:if(chosen)begin owner<=choice;state<=SEND;end
    SEND:if(launch)begin state<=RECEIVE;count<=0;bad<=0;end
    RECEIVE:begin
     if(byte_accept)begin if(count!=1023)count<=count+1'b1;if(framing_bad)bad<=1;end
    end
    default:state<=IDLE;
   endcase
   if(complete)begin
    state<=IDLE;round_robin<=owner==CLIENTS-1?0:owner+1'b1;
    if(complete_error)begin if(sectors_bad!=32'hffffffff)sectors_bad<=sectors_bad+1'b1;end
    else if(sectors_ok!=32'hffffffff)sectors_ok<=sectors_ok+1'b1;
   end
  end
 end
 genvar client;
 generate for(client=0;client<CLIENTS;client=client+1)begin:caches
  reg [2:0] slot;reg [31:0] lba;reg error;
  reg [7:0] ram[0:511];reg [8:0] out_index;reg [7:0] front;
  assign lbas[client]=lba;
  assign waiting[client]=slot==WAITING;
  assign c_ready[client]=rst_n&&slot==FREE;
  assign c_busy[client]=slot!=FREE;
  assign c_data_valid[client]=rst_n&&slot==STREAM;
  assign c_data[client*8+:8]=front;
  assign c_last[client]=c_data_valid[client]&&out_index==511;
  assign c_done_valid[client]=rst_n&&slot==RESULT;
  assign c_error[client]=error;
  wire take=c_data_valid[client]&&c_data_ready[client];
  // NATIVE_STREAM requires backend CRC quarantine before its FIRST byte.
  // The native SDHC controller supplies this contract. Generic backends keep0.
  reg fill_complete;
  wire available_current=fill_complete||(state==RECEIVE&&owner==client&&count>{1'b0,out_index});
  wire [9:0] next_index={1'b0,out_index}+10'd1;
  wire available_next=fill_complete||(state==RECEIVE&&owner==client&&count>next_index);
  wire fetch=NATIVE_STREAM?((slot==FETCH&&available_current)||(take&&out_index!=511&&available_next)):
   (slot==FETCH||(take&&out_index!=511));
  wire [8:0] next_address=slot==FETCH?out_index:out_index+1'b1;
  always @(posedge clk)begin
   if(byte_accept&&owner==client&&count<512)ram[count[8:0]]<=data;
   if(fetch)front<=ram[next_address];
  end
  if(NATIVE_STREAM==0)begin:strict
  always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin slot<=FREE;lba<=0;out_index<=0;error<=0;end
   else case(slot)
    FREE:if(c_request[client])begin lba<=c_lba[client*32+:32];slot<=WAITING;error<=0;end
    WAITING:begin
     if(launch&&owner==client)slot<=FILLING;
     else if(complete&&owner==client)begin error<=1;slot<=RESULT;end
    end
    FILLING:if(complete&&owner==client)begin
     error<=complete_error;out_index<=0;slot<=complete_error?RESULT:FETCH;
    end
    FETCH:slot<=STREAM;
    STREAM:if(take)begin if(out_index==511)slot<=RESULT;else out_index<=out_index+1'b1;end
    RESULT:if(c_done_ready[client])slot<=FREE;
    default:slot<=FREE;
   endcase
  end
  end else begin:native
  always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin slot<=FREE;lba<=0;out_index<=0;error<=0;fill_complete<=0;end
   else begin
    case(slot)
     FREE:if(c_request[client])begin lba<=c_lba[client*32+:32];slot<=WAITING;error<=0;fill_complete<=0;out_index<=0;end
     WAITING:begin
      if(launch&&owner==client)slot<=FILLING;
      else if(complete&&owner==client)begin error<=1;slot<=RESULT;end
     end
     FILLING:if(available_current)slot<=FETCH;
     FETCH:if(available_current)slot<=STREAM;
     STREAM:if(take)begin
      if(out_index==511)slot<=fill_complete?RESULT:WAIT_FINISH;
      else begin out_index<=out_index+1'b1;if(!available_next)slot<=FETCH;end
     end
     WAIT_FINISH:if(fill_complete)slot<=RESULT;
     RESULT:if(c_done_ready[client])slot<=FREE;
     default:slot<=FREE;
    endcase
    // A completed native sector cannot be reused by another client until its
    // physical response is accepted. Client completion never precedes it.
    if(complete&&owner==client)begin
     fill_complete<=1;error<=complete_error;
     if(complete_error)slot<=RESULT;
    end
   end
  end
  end
 end endgenerate
endmodule
