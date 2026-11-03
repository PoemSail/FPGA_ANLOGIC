// Necessary output timing pipeline; actual parent SHA256 d84385a664193128eaf598fdc65eaa41fdbcce518742a9e494d26e821593d9fb
// Four same-cycle two-stage active-high PAD reset replicas; no public timing change.
// Parent SHA256 6986396039c691cfeb5d899cda71e15059d2fde6a508c8043f820e2534f36056
`timescale 1ns/1ps
// Related 1:5 pixel/fast clocks; one symbol per pixel, 10 bits via five DDR pairs.
// A held bundled word crosses on a two-flop toggle plus registered load event.
// Common reset required. Clock lane sends bit sequence 00000 then 11111.
// Physical generated clocks/phase/ODDR placement/timing must be verified later.
module station_tmds_ddr(
 input wire pixel_clk,serial_clk,arst_n,symbol_valid,input wire [29:0] symbols,
 output wire [2:0] serial_data,output wire serial_clock,output reg cadence_error
);
 wire prst,srst;reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 reset_sync sr(.clk(serial_clk),.arst_n(arst_n),.rst_n(srst));
 // Same asynchronous assertion and two serial-edge release as !srst.
 // Dedicated active-high cone avoids a shared high-fanout inverter before
 // the four ODDR reset pins. TD preserve keeps this redundant reset cone;
 // it does not remove normal recovery/removal or data timing checks.
 (* preserve = "true" *) reg [7:0] lane_pad_reset;
 always @(posedge serial_clk or negedge arst_n)begin
  if(!arst_n)lane_pad_reset<=8'hff;
  else lane_pad_reset<={lane_pad_reset[6],1'b0,lane_pad_reset[4],1'b0,lane_pad_reset[2],1'b0,lane_pad_reset[0],1'b0};
 end
 reg [29:0] held;reg toggle,started;reg [4:0] history;
 (* preserve="true" *) reg meta,sync,load;
 // Same-cycle preserved replicas serve separate lanes, reducing load fanout.
 (* preserve="true" *) reg [3:0] lane_load;
 reg [7:0] lane0,lane1,lane2,clock_lane;reg [3:0] rise_pair,fall_pair;
 always @(posedge pixel_clk or negedge prst)begin
  if(!prst)begin held<=0;toggle<=0;end
  else if(symbol_valid)begin held<=symbols;toggle<=!toggle;end
 end
 always @(posedge serial_clk or negedge srst)begin
  if(!srst)begin meta<=0;sync<=0;load<=0;lane_load<=0;end
  else begin meta<=toggle;sync<=meta;load<=meta!=sync;lane_load<={4{meta!=sync}};end
 end
 always @(posedge serial_clk or negedge srst)begin
  if(!srst)begin
   started<=0;history<=0;lane0<=0;lane1<=0;lane2<=0;clock_lane<=0;rise_pair<=0;fall_pair<=0;cadence_error<=0;
  end else begin
   history<={history[3:0],load};
   if(load)begin
    if(started&&!history[4])cadence_error<=1;started<=1;
   end else if(started&&history[4])cadence_error<=1;
   if(lane_load[0])begin rise_pair[0]<=held[0];fall_pair[0]<=held[1];lane0<=held[9:2];end
   else begin rise_pair[0]<=lane0[0];fall_pair[0]<=lane0[1];lane0<={2'b0,lane0[7:2]};end
   if(lane_load[1])begin rise_pair[1]<=held[10];fall_pair[1]<=held[11];lane1<=held[19:12];end
   else begin rise_pair[1]<=lane1[0];fall_pair[1]<=lane1[1];lane1<={2'b0,lane1[7:2]};end
   if(lane_load[2])begin rise_pair[2]<=held[20];fall_pair[2]<=held[21];lane2<=held[29:22];end
   else begin rise_pair[2]<=lane2[0];fall_pair[2]<=lane2[1];lane2<={2'b0,lane2[7:2]};end
   if(lane_load[3])begin rise_pair[3]<=0;fall_pair[3]<=0;clock_lane<=8'b11111000;end
   else begin rise_pair[3]<=clock_lane[0];fall_pair[3]<=clock_lane[1];clock_lane<={2'b0,clock_lane[7:2]};end
  end
 end
 // One shared serial-cycle output pipeline for all three data lanes AND clock.
 // This isolates PAD routing from the symbol/shift/load mux registers.
 // No local reset: the unchanged asynchronous PAD reset hides these values;
 // the parent pair registers clear asynchronously before either release edge.
 // All forwarded data and clock bits acquire exactly one serial cycle latency.
 (* preserve = "true" *) reg [3:0] pad_rise,pad_fall;
 always @(posedge serial_clk)begin
  pad_rise<=rise_pair;pad_fall<=fall_pair;
 end
 genvar lane;
 generate for(lane=0;lane<3;lane=lane+1)begin:ddr_lanes
  EG_LOGIC_ODDR #(.ASYNCRST("ENABLE")) driver(.q(serial_data[lane]),.clk(serial_clk),.d0(pad_rise[lane]),.d1(pad_fall[lane]),.rst(lane_pad_reset[lane*2+1]));
 end endgenerate
 EG_LOGIC_ODDR #(.ASYNCRST("ENABLE")) clock_driver(.q(serial_clock),.clk(serial_clk),.d0(pad_rise[3]),.d1(pad_fall[3]),.rst(lane_pad_reset[7]));
endmodule
