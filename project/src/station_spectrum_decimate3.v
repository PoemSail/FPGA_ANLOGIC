`timescale 1ns/1ps
// Intended input: signed16 mono, 48kHz strobe on >=50MHz business clock.
// 256-word history protects in-flight reads down to128cycles/sample.
// 127 taps, Q17 coefficients, one shared multiplier, output every third input.
module station_spectrum_decimate3(
 input wire clk,rst_n,input wire sample_valid,input wire signed [15:0] sample,
 output reg out_valid,output reg signed [15:0] out_sample,
 output reg [31:0] accepted_samples,dropped_outputs
);
 (*ram_style="bram"*) reg signed [15:0] history[0:255];
 (*rom_style="bram",force_ram*) reg signed [17:0] coeff[0:63];
 initial begin
  coeff[0]=18'sd13;
  coeff[1]=18'sd5;
  coeff[2]=-18'sd13;
  coeff[3]=-18'sd27;
  coeff[4]=-18'sd20;
  coeff[5]=18'sd10;
  coeff[6]=18'sd42;
  coeff[7]=18'sd46;
  coeff[8]=18'sd8;
  coeff[9]=-18'sd51;
  coeff[10]=-18'sd81;
  coeff[11]=-18'sd47;
  coeff[12]=18'sd41;
  coeff[13]=18'sd115;
  coeff[14]=18'sd106;
  coeff[15]=18'sd0;
  coeff[16]=-18'sd133;
  coeff[17]=-18'sd180;
  coeff[18]=-18'sd79;
  coeff[19]=18'sd114;
  coeff[20]=18'sd249;
  coeff[21]=18'sd195;
  coeff[22]=-18'sd39;
  coeff[23]=-18'sd287;
  coeff[24]=-18'sd334;
  coeff[25]=-18'sd102;
  coeff[26]=18'sd262;
  coeff[27]=18'sd467;
  coeff[28]=18'sd309;
  coeff[29]=-18'sd142;
  coeff[30]=-18'sd551;
  coeff[31]=-18'sd559;
  coeff[32]=-18'sd91;
  coeff[33]=18'sd532;
  coeff[34]=18'sd806;
  coeff[35]=18'sd438;
  coeff[36]=-18'sd362;
  coeff[37]=-18'sd984;
  coeff[38]=-18'sd871;
  coeff[39]=18'sd0;
  coeff[40]=18'sd1012;
  coeff[41]=18'sd1329;
  coeff[42]=18'sd568;
  coeff[43]=-18'sd801;
  coeff[44]=-18'sd1716;
  coeff[45]=-18'sd1325;
  coeff[46]=18'sd265;
  coeff[47]=18'sd1910;
  coeff[48]=18'sd2218;
  coeff[49]=18'sd679;
  coeff[50]=-18'sd1750;
  coeff[51]=-18'sd3166;
  coeff[52]=-18'sd2134;
  coeff[53]=18'sd1012;
  coeff[54]=18'sd4064;
  coeff[55]=18'sd4333;
  coeff[56]=18'sd754;
  coeff[57]=-18'sd4804;
  coeff[58]=-18'sd8141;
  coeff[59]=-18'sd5162;
  coeff[60]=18'sd5291;
  coeff[61]=18'sd20099;
  coeff[62]=18'sd33080;
  coeff[63]=18'sd38232;
































































 end
 // Pair taps j and126-j, center63 once; one RAM read port.
 reg [7:0] wp,start;reg [5:0] tap;reg [7:0] count,available;
 reg [1:0] phase;reg [2:0] state;
 reg signed [15:0] history_q,left_q;reg history_usable;
 wire signed [15:0] data_q=history_usable?history_q:16'sd0;reg signed [17:0] coeff_q;
 reg signed [34:0] product_q;reg signed [40:0] accumulator;
 wire [7:0] offset=state==1?{2'b0,tap}:8'd126-{2'b0,tap};
 wire [7:0] address=start-offset;
 wire signed [16:0] paired=$signed({left_q[15],left_q})+$signed({data_q[15],data_q});
 wire signed [40:0] sum=accumulator+$signed({{6{product_q[34]}},product_q});
 wire signed [40:0] rounded=(sum+41'sd65536)>>>17;
 always @(posedge clk)begin
  if(rst_n&&sample_valid)history[wp]<=sample;
  coeff_q<=coeff[tap];
  // Canonical synchronous RAM read; availability zero-fill stays outside RAM.
  if(state==1||state==2)begin
   history_q<=history[address];
   history_usable<=offset<available&&!(state==2&&tap==63);
  end
  if(state==2)left_q<=data_q;
  if(state==3)product_q<=paired*coeff_q;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   wp<=0;start<=0;tap<=0;count<=0;available<=0;phase<=0;state<=0;
   accumulator<=0;out_valid<=0;out_sample<=0;accepted_samples<=0;dropped_outputs<=0;
  end else begin
   out_valid<=0;
   if(sample_valid)begin
    wp<=wp+1'b1;if(count<128)count<=count+1'b1;
    accepted_samples<=accepted_samples+1'b1;
    if(phase==2)begin phase<=0;
     if(state!=0)dropped_outputs<=dropped_outputs+1'b1;
     else begin start<=wp;available<=count<128?count+1'b1:8'd128;tap<=0;accumulator<=0;state<=1;end
    end else phase<=phase+1'b1;
   end
   case(state)
    1:state<=2;
    2:state<=3;
    3:state<=4;
    4:if(tap==63)begin
      out_sample<=rounded>32767?16'sh7fff:rounded< -32768?16'sh8000:rounded[15:0];out_valid<=1;state<=0;
     end else begin accumulator<=sum;tap<=tap+1'b1;state<=1;end
   endcase
  end
 end
endmodule
