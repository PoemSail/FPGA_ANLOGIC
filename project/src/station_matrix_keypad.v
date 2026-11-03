`timescale 1ns/1ps
// Passive4x4 matrix: rows are open drain, columns require board/ADC pullups.
// Code=row*4+column. Events are one bus-clock pulse, code valid with pulse.
// Five identical4ms scans qualify a new press/release at50MHz defaults.
// Startup and any observed multi-key scan require stable ALL-release to arm.
// This module has no board-pin assignment and never drives a row high.
module station_matrix_keypad #(
 parameter integer CLOCK_HZ=50000000,
 parameter integer ROW_HOLD_CYCLES=CLOCK_HZ/1000,
 parameter integer DEBOUNCE_SCANS=5,
 parameter integer LONG_PRESS_CYCLES=CLOCK_HZ
)(
 input wire clk,rst_n,
 input wire [3:0] col_n,
 output wire [3:0] row_n,
 output reg key_valid,output reg [3:0] key_code,
 output reg key_long_valid,output reg [3:0] key_long_code
);
 function integer bits_for;
  input integer n;begin bits_for=0;n=n-1;
   while(n>0)begin bits_for=bits_for+1;n=n>>1;end
   if(bits_for==0)bits_for=1;
  end
 endfunction
 localparam RW=bits_for(ROW_HOLD_CYCLES),DW=bits_for(DEBOUNCE_SCANS+1),LW=bits_for(LONG_PRESS_CYCLES);
 localparam [4:0] NONE=5'd16,MULTI=5'd17;
 reg [1:0] row_index;
 reg [RW-1:0] row_count;
 (* async_reg="true" *) reg [3:0] col_meta,col_sync;
 genvar r;
 generate for(r=0;r<4;r=r+1)begin:open_drain_rows
  assign row_n[r]=rst_n&&(row_index==r)?1'b0:1'bz;
 end endgenerate
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin col_meta<=4'hf;col_sync<=4'hf;end
  else begin col_meta<=col_n;col_sync<=col_meta;end
 end
 reg row_single,row_multi;reg [1:0] column_index;
 always @*begin
  row_single=0;row_multi=0;column_index=0;
  case(col_sync)
   4'b1111:;
   4'b1110:begin row_single=1;column_index=0;end
   4'b1101:begin row_single=1;column_index=1;end
   4'b1011:begin row_single=1;column_index=2;end
   4'b0111:begin row_single=1;column_index=3;end
   default:row_multi=1;
  endcase
 end
 reg scan_single,scan_multi;reg [3:0] scan_key;
 wire [4:0] completed_scan=(scan_multi||row_multi||(scan_single&&row_single))?MULTI:
  row_single?{1'b0,row_index,column_index}:scan_single?{1'b0,scan_key}:NONE;
 reg [4:0] candidate;reg [DW-1:0] same_scans;
 reg armed,pressed,long_sent;reg [3:0] active_key;
 reg [LW-1:0] long_count;
 wire row_end=row_count==ROW_HOLD_CYCLES-1;
 wire scan_end=row_end&&row_index==3;
 wire stable_now=(completed_scan==candidate)?same_scans>=DEBOUNCE_SCANS-1:DEBOUNCE_SCANS<=1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   row_index<=0;row_count<=0;scan_single<=0;scan_multi<=0;scan_key<=0;
   candidate<=MULTI;same_scans<=0;armed<=0;pressed<=0;active_key<=0;
   long_count<=0;long_sent<=0;key_valid<=0;key_code<=0;key_long_valid<=0;key_long_code<=0;
  end else begin
   key_valid<=0;key_long_valid<=0;
   if(pressed&&!long_sent)begin
    if(long_count==LONG_PRESS_CYCLES-1)begin
     key_long_valid<=1;key_long_code<=active_key;long_sent<=1;
    end else long_count<=long_count+1'b1;
   end
   if(row_end)begin
    row_count<=0;row_index<=row_index+1'b1;
    if(row_index==3)begin
     scan_single<=0;scan_multi<=0;scan_key<=0;
     if(completed_scan==candidate)begin
      if(same_scans<DEBOUNCE_SCANS)same_scans<=same_scans+1'b1;
     end else begin candidate<=completed_scan;same_scans<=1;end
     // Reject a multi/ghost graph immediately at full-scan granularity.
     // Never turn an invalid/different held combination into a new key.
     if(completed_scan==MULTI)begin
      armed<=0;pressed<=0;long_count<=0;long_sent<=0;key_long_valid<=0;
     end else begin
      if(pressed&&completed_scan!={1'b0,active_key})begin
       pressed<=0;long_count<=0;long_sent<=0;key_long_valid<=0;
      end
      if(stable_now)begin
       if(completed_scan==NONE)begin
        armed<=1;pressed<=0;long_count<=0;long_sent<=0;key_long_valid<=0;
       end else if(armed)begin
        key_valid<=1;key_code<=completed_scan[3:0];armed<=0;
        pressed<=1;active_key<=completed_scan[3:0];long_count<=0;long_sent<=0;
       end
      end
     end
    end else begin
     if(row_single)begin scan_single<=1;scan_key<={row_index,column_index};end
     if(row_multi||(scan_single&&row_single))scan_multi<=1;
    end
   end else row_count<=row_count+1'b1;
  end
 end
endmodule
