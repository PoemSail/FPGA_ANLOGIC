`timescale 1ns/1ps
// 64-point radix-2 DIT FFT, real signed16 input, bit-reversed load.
// Every butterfly divides by 2; outputs are FFT(input)/64, Q1.15 twiddles.
// R19: one pipelined shared multiplier; four sequential products; original fixed-point results.
module fft64_compute_r19(
 input wire clk,rst_n,input wire sample_valid,input wire signed [15:0] sample,
 output wire sample_ready,output wire bin_valid,input wire bin_ready,
 output reg [5:0] bin_index,output wire signed [15:0] bin_real,bin_imag,
 output reg [31:0] blocks
);
 reg [3:0] state;reg [5:0] fill,group_base,j,ia,ib,tw;
 reg [2:0] stage;reg [6:0] half_size;
 reg [31:0] memory[0:63];reg [31:0] ram_data;reg [5:0] read_address,write_address;
 reg write_enable;reg [31:0] write_data;
 reg signed [15:0] ar,ai,br,bi,wr,wi;
 reg signed [15:0] mul_a,mul_b;
 reg signed [31:0] product_reg;
 always @*begin
  mul_a=0;mul_b=0;
  case(state)
   5:begin mul_a=br;mul_b=wr;end
   12:begin mul_a=bi;mul_b=wi;end
   13:begin mul_a=br;mul_b=wi;end
   14:begin mul_a=bi;mul_b=wr;end
  endcase
 end
 always @(posedge clk)product_reg<=mul_a*mul_b;
 reg signed [31:0] p0,p1,p2,p3;reg signed [17:0] tr,ti;
 wire signed [18:0] sumr=$signed(ar)+tr,sumi=$signed(ai)+ti,difr=$signed(ar)-tr,difi=$signed(ai)-ti;
 assign sample_ready=rst_n&&state==0;
 assign bin_valid=rst_n&&state==7;assign bin_real=ar;assign bin_imag=ai;
 always @*begin
  read_address=bin_index;write_enable=0;write_address=0;write_data=0;
  if(state==2)read_address=ia;else if(state==3)read_address=ib;
  if(state==0&&sample_valid)begin write_enable=1;write_address=reverse6(fill);write_data={sample,16'b0};end
  else if(state==9)begin write_enable=1;write_address=ia;write_data={sumr[16:1],sumi[16:1]};end
  else if(state==10)begin write_enable=1;write_address=ib;write_data={difr[16:1],difi[16:1]};end
 end
 // Single synchronous read/write: maps to one BRAM, not thousands of muxes.
 always @(posedge clk)begin
  if(rst_n&&write_enable)memory[write_address]<=write_data;
  if(state==2||state==3||state==6)ram_data<=memory[read_address];
 end
 function [5:0] reverse6;input [5:0] v;begin reverse6={v[0],v[1],v[2],v[3],v[4],v[5]};end endfunction
 function signed [15:0] cosine;input [5:0] a;begin case(a)
  0:cosine=32767;1:cosine=32610;2:cosine=32138;3:cosine=31357;
  4:cosine=30274;5:cosine=28899;6:cosine=27246;7:cosine=25330;
  8:cosine=23170;9:cosine=20788;10:cosine=18205;11:cosine=15447;
  12:cosine=12540;13:cosine=9512;14:cosine=6393;15:cosine=3212;
  16:cosine=0;17:cosine=-3212;18:cosine=-6393;19:cosine=-9512;
  20:cosine=-12540;21:cosine=-15447;22:cosine=-18205;23:cosine=-20788;
  24:cosine=-23170;25:cosine=-25330;26:cosine=-27246;27:cosine=-28899;
  28:cosine=-30274;29:cosine=-31357;30:cosine=-32138;31:cosine=-32610;
  default:cosine=-32768;endcase end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=0;fill<=0;group_base<=0;j<=0;ia<=0;ib<=0;tw<=0;stage<=0;half_size<=1;
   ar<=0;ai<=0;br<=0;bi<=0;wr<=0;wi<=0;p0<=0;p1<=0;p2<=0;p3<=0;tr<=0;ti<=0;bin_index<=0;blocks<=0;end
  else begin
   case(state)
    0:if(sample_valid)begin
     if(fill==63)begin fill<=0;stage<=0;half_size<=1;group_base<=0;j<=0;state<=1;end else fill<=fill+1'b1;end
    1:begin ia<=group_base+j;ib<=group_base+j+half_size;tw<=j<<(5-stage);state<=2;end
    2:state<=3;
    3:begin ar<=ram_data[31:16];ai<=ram_data[15:0];wr<=cosine(tw);wi<=-cosine(tw<=16 ? 16-tw:tw-16);state<=4;end
    4:begin br<=ram_data[31:16];bi<=ram_data[15:0];state<=5;end
    5:state<=12;
    12:begin p0<=product_reg;state<=13;end
    13:begin p1<=product_reg;state<=14;end
    14:begin p2<=product_reg;state<=15;end
    15:begin p3<=product_reg;state<=8;end
    8:begin tr<=($signed({p0[31],p0})-$signed({p1[31],p1}))>>>15;
     ti<=($signed({p2[31],p2})+$signed({p3[31],p3}))>>>15;state<=9;end
    9:state<=10;
    10:begin
     if(j+1<half_size)begin j<=j+1'b1;state<=1;end
     else if({1'b0,group_base}+(half_size<<1)<64)begin group_base<=group_base+(half_size<<1);j<=0;state<=1;end
     else if(stage<5)begin stage<=stage+1'b1;half_size<=half_size<<1;group_base<=0;j<=0;state<=1;end
     else begin bin_index<=0;state<=6;end
    end
    6:state<=11;
    11:begin ar<=ram_data[31:16];ai<=ram_data[15:0];state<=7;end
    7:if(bin_ready)begin if(bin_index==63)begin blocks<=blocks+1'b1;state<=0;end else begin bin_index<=bin_index+1'b1;state<=6;end end
   endcase
  end
 end
endmodule
