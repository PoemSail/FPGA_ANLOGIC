`timescale 1ns/1ps
// Business-domain final PCM + continuous pixel-domain RGB -> HDMI ODDR/pads.
// External clock contract: 50MHz business, 74.25MHz pixel, related371.25MHz serial.
// PLL/clock placement, output electrical constraints and board validation pending.
module station_hdmi_tx(
 input wire bus_clk,pixel_clk,serial_clk,arst_n,
 input wire [11:0] x,y,input wire [23:0] rgb,input wire de,hs,vs,
 input wire audio_valid,input wire [15:0] audio_left,audio_right,
 output wire [2:0] hdmi_data_p,output wire hdmi_clock_p,
 output wire cdc_overflow,packet_overflow,cadence_error,output wire [31:0] audio_dropped,
 output wire [31:0] audio_packets,acr_packets,info_packets
);
 wire prst;reset_sync pr(.clk(pixel_clk),.arst_n(arst_n),.rst_n(prst));
 wire sample_valid,sample_ready,unused_source_ready;wire [15:0] sample_left,sample_right;
 station_audio_cdc transfer(.src_clk(bus_clk),.dst_clk(pixel_clk),.arst_n(arst_n),
  .src_valid(audio_valid),.src_left(audio_left),.src_right(audio_right),.src_ready(unused_source_ready),
  .dst_valid(sample_valid),.dst_ready(sample_ready),.dst_left(sample_left),.dst_right(sample_right),.overflow(cdc_overflow),.dropped(audio_dropped));
 wire symbol_valid;wire [29:0] symbols;wire [2:0] serial_data;wire serial_clock;
 station_hdmi_stream stream(.clk(pixel_clk),.rst_n(prst),.pixel_valid(1'b1),.x(x),.y(y),.rgb(rgb),.de(de),.hs(hs),.vs(vs),
  .audio_valid(sample_valid),.audio_ready(sample_ready),.audio_left(sample_left),.audio_right(sample_right),
  .symbol_valid(symbol_valid),.symbols(symbols),.audio_overflow(packet_overflow),
  .audio_packets(audio_packets),.acr_packets(acr_packets),.info_packets(info_packets));
 station_tmds_ddr serializer(.pixel_clk(pixel_clk),.serial_clk(serial_clk),.arst_n(arst_n),.symbol_valid(symbol_valid),.symbols(symbols),
  .serial_data(serial_data),.serial_clock(serial_clock),.cadence_error(cadence_error));
 eg4_hdmi_pads pads(.data(serial_data),.clock(serial_clock),.hdmi_data_p(hdmi_data_p),.hdmi_clock_p(hdmi_clock_p));
endmodule
