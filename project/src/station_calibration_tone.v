`timescale 1ns/1ps
// 1kHz sine at the existing exact48000Hz physical tick. Stereo duplication
// and shared volume/FFT/HDMI remain in the passenger's final PCM path.
module station_calibration_tone(input wire clk,rst_n,physical_tick,enable,
 output reg sample_valid,output reg signed [15:0] sample);
 reg [5:0] phase;reg signed [15:0] wave;
 always @*begin
  case(phase)
   6'd0:wave=16'sd0;
   6'd1:wave=16'sd1069;
   6'd2:wave=16'sd2120;
   6'd3:wave=16'sd3135;
   6'd4:wave=16'sd4096;
   6'd5:wave=16'sd4987;
   6'd6:wave=16'sd5793;
   6'd7:wave=16'sd6499;
   6'd8:wave=16'sd7094;
   6'd9:wave=16'sd7568;
   6'd10:wave=16'sd7913;
   6'd11:wave=16'sd8122;
   6'd12:wave=16'sd8192;
   6'd13:wave=16'sd8122;
   6'd14:wave=16'sd7913;
   6'd15:wave=16'sd7568;
   6'd16:wave=16'sd7094;
   6'd17:wave=16'sd6499;
   6'd18:wave=16'sd5793;
   6'd19:wave=16'sd4987;
   6'd20:wave=16'sd4096;
   6'd21:wave=16'sd3135;
   6'd22:wave=16'sd2120;
   6'd23:wave=16'sd1069;
   6'd24:wave=16'sd0;
   6'd25:wave=-16'sd1069;
   6'd26:wave=-16'sd2120;
   6'd27:wave=-16'sd3135;
   6'd28:wave=-16'sd4096;
   6'd29:wave=-16'sd4987;
   6'd30:wave=-16'sd5793;
   6'd31:wave=-16'sd6499;
   6'd32:wave=-16'sd7094;
   6'd33:wave=-16'sd7568;
   6'd34:wave=-16'sd7913;
   6'd35:wave=-16'sd8122;
   6'd36:wave=-16'sd8192;
   6'd37:wave=-16'sd8122;
   6'd38:wave=-16'sd7913;
   6'd39:wave=-16'sd7568;
   6'd40:wave=-16'sd7094;
   6'd41:wave=-16'sd6499;
   6'd42:wave=-16'sd5793;
   6'd43:wave=-16'sd4987;
   6'd44:wave=-16'sd4096;
   6'd45:wave=-16'sd3135;
   6'd46:wave=-16'sd2120;
   6'd47:wave=-16'sd1069;
   default:wave=0;
  endcase
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin phase<=0;sample_valid<=0;sample<=0;end
  else begin
   sample_valid<=physical_tick&&enable;
   if(!enable)begin phase<=0;sample<=0;end
   else if(physical_tick)begin sample<=wave;phase<=phase==47?0:phase+1'b1;end
  end
 end
endmodule
