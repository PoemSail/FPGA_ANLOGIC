`timescale 1ns/1ps
// Unsigned restoring division, one transaction, 32 iterations. Denominator must be nonzero.
module unsigned_divider(input wire clk,rst_n,start,input wire [31:0] numerator,input wire [15:0] denominator,
 output reg busy,done,output reg [31:0] quotient);
 reg [31:0] work;reg [16:0] remainder;reg [15:0] divisor;reg [5:0] count;
 wire [16:0] trial={remainder[15:0],work[31]};wire subtract=trial>={1'b0,divisor};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin busy<=0;done<=0;quotient<=0;work<=0;remainder<=0;divisor<=1;count<=0;end
  else begin
   done<=0;
   if(start&&!busy)begin work<=numerator;divisor<=denominator;remainder<=0;count<=0;busy<=1;end
   else if(busy)begin
    remainder<=subtract?trial-{1'b0,divisor}:trial;work<={work[30:0],subtract};
    if(count==31)begin quotient<={work[30:0],subtract};busy<=0;done<=1;end else count<=count+1'b1;
   end
  end
 end
endmodule
