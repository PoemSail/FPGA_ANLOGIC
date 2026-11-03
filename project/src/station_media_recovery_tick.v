// time_tick must be a business-domain enable independent of pixel/SD clocks.
// Default5000 ticks at1ms/tick is5seconds; reset/quiet are still bus clocks.
`timescale 1ns/1ps
// Global media recovery coordinator, BUSINESS-clock/reset domain.
// A rising retry_request is accepted only when retry_ready. Busy requests are
// discarded, not queued. Caller keeps keys, scene/emergency, tone, raster and
// HDMI clocks OUTSIDE reset_group, and gives all media/file/memory clients the
// SAME reset assertion with synchronized releases in their clock domains.
// cancel_all stops NEW work but must not mask accepted response/drain paths.
// During PREFETCH allow producers to run while hold_consumption stays high.
// Timeouts retain a safe cancelled state; they NEVER force-reset busy memory.
module station_media_recovery_tick #(
 parameter integer RESET_CLOCKS=16,QUIET_CLOCKS=2,TIMEOUT_TICKS=5000
)(
 input wire clk,rst_n,retry_request,fault,time_tick,
 input wire files_quiet,core_quiet,photo_quiet,backend_quiet,safe_frame,
 input wire memory_initialized,storage_initialized,media_ready,
 output wire retry_ready,busy,cancel_all,reset_group,allow_prefetch,hold_consumption,
 output reg accepted,completed,output reg [3:0] error_code,output reg [2:0] state
);
 function integer bits_for;input integer n;begin bits_for=0;n=n-1;
  while(n>0)begin bits_for=bits_for+1;n=n>>1;end if(bits_for==0)bits_for=1;end endfunction
 localparam IDLE=0,DRAIN=1,RESET=2,REINIT=3,PREFETCH=4,FAILED=5;
 localparam TW=bits_for(TIMEOUT_TICKS),RW=bits_for(RESET_CLOCKS),QW=bits_for(QUIET_CLOCKS+1);
 reg previous_retry,seen_memory_low,seen_storage_low;
 reg [TW-1:0] timer;reg [RW-1:0] reset_count;reg [QW-1:0] quiet_count;
 wire all_quiet=files_quiet&&core_quiet&&photo_quiet&&backend_quiet;
 wire take=retry_request&&!previous_retry&&retry_ready;
 assign retry_ready=rst_n&&(state==IDLE||state==FAILED);
 assign busy=rst_n&&state!=IDLE;
 assign reset_group=rst_n&&state==RESET;
 assign cancel_all=rst_n&&(state==DRAIN||state==RESET||state==REINIT||state==FAILED||(state==IDLE&&fault));
 assign allow_prefetch=rst_n&&((state==IDLE&&!fault)||state==PREFETCH);
 assign hold_consumption=!rst_n||state!=IDLE||fault;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;previous_retry<=0;seen_memory_low<=0;seen_storage_low<=0;
   timer<=0;reset_count<=0;quiet_count<=0;accepted<=0;completed<=0;error_code<=0;
  end else begin
   previous_retry<=retry_request;accepted<=0;completed<=0;
   if(take)begin
    state<=DRAIN;timer<=0;reset_count<=0;quiet_count<=0;error_code<=0;
    seen_memory_low<=0;seen_storage_low<=0;accepted<=1;
   end else case(state)
    IDLE:begin timer<=0;quiet_count<=0;if(fault)begin state<=FAILED;error_code<=6;end end
    DRAIN:begin
     if(all_quiet)begin if(quiet_count<QUIET_CLOCKS)quiet_count<=quiet_count+1'b1;end
     else quiet_count<=0;
     if(all_quiet&&quiet_count>=QUIET_CLOCKS-1&&safe_frame)begin state<=RESET;reset_count<=0;timer<=0;end
     else if(time_tick)begin
      if(timer>=TIMEOUT_TICKS-1)begin state<=FAILED;error_code<=1;end
      else timer<=timer+1'b1;
     end
    end
    RESET:begin
     if(!memory_initialized)seen_memory_low<=1;
     if(!storage_initialized)seen_storage_low<=1;
     if(reset_count>=RESET_CLOCKS-1)begin state<=REINIT;timer<=0;end
     else reset_count<=reset_count+1'b1;
    end
    REINIT:begin
     if(seen_memory_low&&seen_storage_low&&memory_initialized&&storage_initialized&&!fault)begin state<=PREFETCH;timer<=0;end
     else if(time_tick)begin
      if(timer>=TIMEOUT_TICKS-1)begin state<=FAILED;error_code<=2;end
      else timer<=timer+1'b1;
     end
    end
    PREFETCH:begin
     if(fault)begin state<=FAILED;error_code<=4;end
     else if(media_ready&&safe_frame)begin state<=IDLE;timer<=0;completed<=1;end
     else if(time_tick)begin
      if(timer>=TIMEOUT_TICKS-1)begin state<=FAILED;error_code<=3;end
      else timer<=timer+1'b1;
     end
    end
    FAILED:;
    default:begin state<=FAILED;error_code<=5;end
   endcase
  end
 end
endmodule
