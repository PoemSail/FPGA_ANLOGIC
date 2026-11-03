`timescale 1ns/1ps
// Bounded continuous-input queue. Analysis never backpressures the PCM player.
// Reset cancels all partial input blocks; unaccepted samples are counted explicitly.
module station_spectrum_fft512_queue(
 input wire clk,rst_n,input wire sample_valid,input wire signed [15:0] sample,
 output wire sample_ready,output wire bin_valid,input wire bin_ready,
 output wire [8:0] bin_index,output wire signed [17:0] bin_real,bin_imag,
 output wire [31:0] blocks,output reg [31:0] dropped_samples,accepted_samples
);
 reg [15:0] memory[0:127];reg [6:0] wp,rp;reg [7:0] count;
 reg [15:0] front;reg front_valid;
 wire compute_ready;wire take=front_valid&&compute_ready;
 assign sample_ready=rst_n&&(count<128||take);
 wire put=sample_valid&&sample_ready;
 always @(posedge clk)begin
  if(put)memory[wp]<=sample;
  if(!front_valid&&count!=0)front<=memory[rp];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin wp<=0;rp<=0;count<=0;front_valid<=0;dropped_samples<=0;accepted_samples<=0;end
  else begin
   if(sample_valid&&!sample_ready)dropped_samples<=dropped_samples+1'b1;
   if(put)begin wp<=wp+1'b1;accepted_samples<=accepted_samples+1'b1;end
   if(!front_valid&&count!=0)front_valid<=1;
   if(take)begin rp<=rp+1'b1;front_valid<=0;end
   case({put,take})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
  end
 end
 station_spectrum_fft512 compute(.clk(clk),.rst_n(rst_n),.sample_valid(front_valid),.sample($signed(front)),
  .sample_ready(compute_ready),.bin_valid(bin_valid),.bin_ready(bin_ready),.bin_index(bin_index),
  .bin_real(bin_real),.bin_imag(bin_imag),.blocks(blocks));
endmodule
