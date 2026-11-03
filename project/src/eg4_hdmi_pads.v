`timescale 1ns/1ps
// TD expands each LVDS33 positive output into its physical negative companion.
// Do not add separate inverted fabric outputs on the reserved negative pads.
// Electrical assumption: board accepts this differential driver without external transmitter.
module eg4_hdmi_pads(input wire [2:0] data,input wire clock,
 output wire [2:0] hdmi_data_p,output wire hdmi_clock_p);
 EG_LOGIC_OBUF lane0(.i(data[0]),.o(hdmi_data_p[0]));
 EG_LOGIC_OBUF lane1(.i(data[1]),.o(hdmi_data_p[1]));
 EG_LOGIC_OBUF lane2(.i(data[2]),.o(hdmi_data_p[2]));
 EG_LOGIC_OBUF clock_lane(.i(clock),.o(hdmi_clock_p));
endmodule
