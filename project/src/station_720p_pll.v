`timescale 1ns/100fs
// Candidate EG4S20 clock tree, from the user-confirmed25MHz H3 reference.
// Master:25*22=550MHz VCO, /11=50MHz, /20=27.5MHz.
// Video:27.5*27=742.5MHz VCO, /10=74.25MHz, /2=371.25MHz.
// Memory:/11, (3+1+5/8)/550MHz =+8.4090909ns phase candidate.
// Loop constants retain the supplied PLL profile. They are NOT regenerated
// analog calibration or a silicon lock/jitter guarantee. Physical PLL range,
// cascade placement/clock paths and SDRAM phase require native/board closure.
module station_720p_pll(
 input wire refclk,reset,
 output wire bus_clk,pixel_clk,serial_clk,memory_clk,
 output wire primary_locked,video_locked
);
 wire [4:0] master_clkc,video_clkc;wire bridge_clk;
 EG_LOGIC_BUFG bus_buffer(.i(master_clkc[0]),.o(bus_clk));
 EG_LOGIC_BUFG bridge_buffer(.i(master_clkc[1]),.o(bridge_clk));
 EG_LOGIC_BUFG memory_buffer(.i(master_clkc[2]),.o(memory_clk));
 EG_LOGIC_BUFG pixel_buffer(.i(video_clkc[0]),.o(pixel_clk));
 EG_LOGIC_BUFG serial_buffer(.i(video_clkc[1]),.o(serial_clk));
 EG_PHY_PLL #(.FIN("25.000"),.FEEDBK_MODE("NOCOMP"),.FEEDBK_PATH("VCO_PHASE_0"),
  .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.STDBY_ENABLE("DISABLE"),
  .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),.DERIVE_PLL_CLOCKS("DISABLE"),.GEN_BASIC_CLOCK("DISABLE"),
  .GMC_GAIN(0),.ICP_CURRENT(9),.KVCO(2),.LPF_CAPACITOR(2),.LPF_RESISTOR(8),
  .REFCLK_DIV(1),.FBCLK_DIV(22),
  .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(11),.CLKC0_CPHASE(10),.CLKC0_FPHASE(0),
  .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(20),.CLKC1_CPHASE(19),.CLKC1_FPHASE(0),
  .CLKC2_ENABLE("ENABLE"),.CLKC2_DIV(11),.CLKC2_CPHASE(3),.CLKC2_FPHASE(5))
 master(.refclk(refclk),.reset(reset),.stdby(1'b0),.extlock(primary_locked),
  .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'd0),.psdone(),
  .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'd0),.daddr(6'd0),.do(),.fbclk(1'b0),.clkc(master_clkc));
 EG_PHY_PLL #(.FIN("27.500"),.FEEDBK_MODE("NOCOMP"),.FEEDBK_PATH("VCO_PHASE_0"),
  .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.STDBY_ENABLE("DISABLE"),
  .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),.DERIVE_PLL_CLOCKS("DISABLE"),.GEN_BASIC_CLOCK("DISABLE"),
  .GMC_GAIN(0),.ICP_CURRENT(9),.KVCO(2),.LPF_CAPACITOR(2),.LPF_RESISTOR(8),
  .REFCLK_DIV(1),.FBCLK_DIV(27),
  .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(10),.CLKC0_CPHASE(9),.CLKC0_FPHASE(0),
  .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(2),.CLKC1_CPHASE(1),.CLKC1_FPHASE(0))
 video(.refclk(bridge_clk),.reset(reset||!primary_locked),.stdby(1'b0),.extlock(video_locked),
  .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'd0),.psdone(),
  .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'd0),.daddr(6'd0),.do(),.fbclk(1'b0),.clkc(video_clkc));
endmodule
