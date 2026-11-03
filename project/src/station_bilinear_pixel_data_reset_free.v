// Candidate: only 146 internal data reset loads removed; select one module source.
`timescale 1ns/1ps
// Offline photo scaler arithmetic: four RGB888 neighbours, Q0.8 fractions.
// output = floor((sum of four nonnegative Q16 weights +32768)/65536).
// One signed17x9 multiplier shared across RGB and horizontal/vertical stages.
// One transaction at a time, nine compute clocks; output held under stall.
// Coordinates, source storage, aspect fitting and frame publication are external.
module station_bilinear_pixel(
 input wire clk,rst_n,in_valid,output wire in_ready,
 input wire [23:0] p00,p10,p01,p11,input wire [7:0] fraction_x,fraction_y,
 output wire out_valid,input wire out_ready,output wire [23:0] rgb
);
 localparam IDLE=0,TOP=1,BOTTOM=2,VERTICAL=3,RESULT=4;
 reg [2:0] state;reg [1:0] channel;
 reg [23:0] a,b,c,d,result;reg [7:0] fx,fy;
 reg signed [16:0] top,bottom;
 wire [7:0] ca=a[channel*8+:8],cb=b[channel*8+:8],cc=c[channel*8+:8],cd=d[channel*8+:8];
 wire signed [8:0] dt=$signed({1'b0,cb})-$signed({1'b0,ca});
 wire signed [8:0] db=$signed({1'b0,cd})-$signed({1'b0,cc});
 reg signed [16:0] multiplier_a;reg signed [8:0] multiplier_b;
 always @*begin
  multiplier_a=0;multiplier_b=$signed({1'b0,fx});
  case(state)
   TOP:multiplier_a={{8{dt[8]}},dt};
   BOTTOM:multiplier_a={{8{db[8]}},db};
   VERTICAL:begin multiplier_a=bottom-top;multiplier_b=$signed({1'b0,fy});end
   default:;
  endcase
 end
 wire signed [25:0] product=multiplier_a*multiplier_b;
 wire signed [25:0] top_sum=$signed({1'b0,ca,8'd0})+product;
 wire signed [25:0] bottom_sum=$signed({1'b0,cc,8'd0})+product;
 wire signed [25:0] vertical_sum=$signed({top[16],top,8'd0})+product+26'sd32768;
 assign in_ready=rst_n&&state==IDLE;
 assign out_valid=rst_n&&state==RESULT;assign rgb=result;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;channel<=0;result<=0;end
  else case(state)
   IDLE:if(in_valid)begin channel<=0;state<=TOP;end
   TOP:begin state<=BOTTOM;end
   BOTTOM:begin state<=VERTICAL;end
   VERTICAL:begin
    result[channel*8+:8]<=vertical_sum[23:16];
    if(channel==2)state<=RESULT;else begin channel<=channel+1'b1;state<=TOP;end
   end
   RESULT:if(out_ready)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
 // Data is overwritten before use in every accepted transaction.
 // Keep state/channel/result asynchronously reset, including public rgb.
 // Aborts never publish uninitialized data: TOP/BOTTOM overwrite each channel.
 always @(posedge clk)begin
  if(rst_n)case(state)
   IDLE:if(in_valid)begin a<=p00;b<=p10;c<=p01;d<=p11;fx<=fraction_x;fy<=fraction_y;end
   TOP:top<=top_sum[16:0];
   BOTTOM:bottom<=bottom_sum[16:0];
   default:;
  endcase
 end
endmodule
