# Complete independent CDC candidate: stable payload nets and clock domains.
# Same25MHz reference, actual PLL-derived clocks, same13ns payload budgets.
# No wholeclock-pair cuts. Every scoped exception requires detailed native
# endpoint audit; tool read/export success alone is insufficient.
create_clock -name ref_25m -period 40.000 [get_ports clk_25m]
derive_clocks
# Bundled UI holds until acknowledged. Source data is stable for >=2pixel
# periods before destination frame capture;13ns preserves settling margin.
set_max_delay -datapath_only -from [get_clocks {clocks/master.clkc[0]}] -through [get_nets {station/station/core/ui_mailbox/held[*]}] -to [get_clocks {clocks/video.clkc[0]}] 13.000
# Existing audited6-bit Gray constraints retained, including aliased MSB.
set_max_delay -datapath_only -from [get_regs {station/station/hdmi/transfer/wg[*]}] -to [get_regs {station/station/hdmi/transfer/wm[*]}] 13.000
set_max_delay -datapath_only -from [get_regs {station/station/hdmi/transfer/rg[*]}] -to [get_regs {station/station/hdmi/transfer/rm[*]}] 13.000
set_path_skew -from [get_regs {station/station/hdmi/transfer/wg[*]}] -to [get_regs {station/station/hdmi/transfer/wm[*]}] 13.000
set_path_skew -from [get_regs {station/station/hdmi/transfer/rg[*]}] -to [get_regs {station/station/hdmi/transfer/rm[*]}] 13.000
# Only first sampling stages are asynchronous. Their local stage2 D paths
# remain timed. No change to the original protocol or reset assertions.
set_false_path -to [get_regs {station/station/core/ui_mailbox/req_meta}]
set_false_path -to [get_regs {station/station/core/ui_mailbox/ack_meta}]
set_false_path -to [get_regs {station/station/core/video/visual/bridge/line_meta}]
set_false_path -to [get_regs {station/station/core/video/visual/bridge/window_meta}]
set_false_path -to [get_regs {station/station/core/video/visual/bridge/ack_meta}]
set_false_path -to [get_regs {station/station/core/video/visual/bridge/desc_meta}]
set_false_path -to [get_regs {station/station/core/video/visual/bridge/fault_meta}]
set_false_path -to [get_regs {station/station/core/video/persistent_raster/frame_meta}]
set_false_path -to [get_regs {station/pixel_fault_transfer/fault_meta}]
# The pixel request payload stays held through the two-stage bus request
# and the matching two-stage acknowledgement. Use actual held source nets;
# do not depend on optimized row_pts/b_state_reg_syn aliases or copies.
set_max_delay -datapath_only -from [get_clocks {clocks/video.clkc[0]}] -through [get_nets {station/station/core/video/visual/bridge/p_request_pts[*] station/station/core/video/visual/bridge/p_request_row[*] station/station/core/video/visual/bridge/p_request_bank}] -to [get_clocks {clocks/master.clkc[0]}] 13.000
# Bus descriptor is sampled after2pixel synchronizer stages plus an extra
# settle cycle. The line result is captured after its2-stage ack and held.
set_max_delay -datapath_only -from [get_clocks {clocks/master.clkc[0]}] -through [get_nets {station/station/core/video/visual/bridge/b_desc_pts[*] station/station/core/video/visual/bridge/b_desc_width[*] station/station/core/video/visual/bridge/b_desc_height[*] station/station/core/video/visual/bridge/b_desc_valid station/station/core/video/visual/bridge/b_line_ok}] -to [get_clocks {clocks/video.clkc[0]}] 13.000
# Actual rawreset entry scope. Audit only SR/RST recovery/removal paths;
# local reset synchronizers and all released fanout remain normally timed.
set_false_path -from [get_clocks {ref_25m}] -through [get_nets {guard/logic_reset_n}] -to [get_clocks {clocks/master.clkc[0] clocks/video.clkc[0] clocks/video.clkc[1]}]
set_false_path -from [get_clocks {clocks/master.clkc[0]}] -through [get_nets {station/client_reset_reg}] -to [get_clocks {clocks/video.clkc[0]}]
# Registered symbol load captures >=2fast periods after pixel held update.
# Exactly30held data paths; retain the ordinary0ns hold relationship.
set_multicycle_path -setup -end -from [get_clocks {clocks/video.clkc[0]}] -through [get_nets {station/station/hdmi/serializer/held[*]}] -to [get_clocks {clocks/video.clkc[1]}] 2
set_multicycle_path -hold -end -from [get_clocks {clocks/video.clkc[0]}] -through [get_nets {station/station/hdmi/serializer/held[*]}] -to [get_clocks {clocks/video.clkc[1]}] 1
# ExternalSD4 initialization/transfer, HDMI electricaltiming and sensorpins
# still require their own reviewed interface constraints. Not release SDC.

# SD25 conditional engineering contract. This is not HDMI electrical signoff.
# DATA_HALF_PERIOD=1,50MHz host,25MHz card clock; CMD launch at fallingCE.
# RX captures on NEXT fallingCE,40ns after the previous card launch.
# Full4lane CRC/quarantine/retry matrix and boundedpin sweep passed.
# Card max14ns/setup5ns/hold5ns: Synopsys SD3.0 SDR12 primary table.
# Conditional bounds: clock out<=8ns, eachPCB leg<=2ns =>returnmax26ns.
# inputmin2ns is below the priorroute clockPADminimum3.091ns; MUST re-audit
# actual SDCLK min/max for this NEW route before crediting this input bound.
# Card andwire minimum only assumed nonnegative; no measured PCB claim.
# set_output_delay -clock [get_clocks {clocks/master.clkc[0]}] -max 12.000 [get_ports sd_clk]
# set_output_delay -clock [get_clocks {clocks/master.clkc[0]}] -min 0.000 [get_ports sd_clk]
set_input_delay -clock [get_clocks {clocks/master.clkc[0]}] -max 26.000 [get_ports {sd_cmd sd_dat[*]}]
set_input_delay -clock [get_clocks {clocks/master.clkc[0]}] -min 2.000 [get_ports {sd_cmd sd_dat[*]}]
set_multicycle_path -setup -end -from [get_ports {sd_cmd sd_dat[*]}] 2
set_multicycle_path -hold -end -from [get_ports {sd_cmd sd_dat[*]}] 1
# CMD available only20ns before next card rising edge, not the old40ns.
set_output_delay -clock [get_clocks {clocks/master.clkc[0]}] -max 7.000 [get_ports sd_cmd]
set_output_delay -clock [get_clocks {clocks/master.clkc[0]}] -min -7.000 [get_ports sd_cmd]
set_multicycle_path -setup -start -to [get_ports sd_cmd] 1
set_multicycle_path -hold -start -to [get_ports sd_cmd] 1
# Initialization remains390625Hz/risingreceive and requires a SEPARATE
# mode analysis with returnmax62ns/receivebudget1280ns. Never use init
# relaxation as proof of25MHz data paths. No internalreg path relaxed here.

# Asynchronous human/sensor inputs: only the first sampling stage is cut.
# Every async port has exactly one registered PAD fanout; cut ends at that first FF.
# PAD-Q to second-stage FF remains timed. Native logical meta names were absorbed.
set_false_path -from [get_ports {keypad_cols_n[*] pir_async light_async}]

# Spectrum bank ownership20261030: WIDTH2 {data_valid,bank}, same held-until-ack
# protocol as ui_mailbox. Only first sampling FFs are asynchronous; local stage2
# remains timed. Two held bits settle within13ns before request can be consumed
# after two pixel synchronizer stages at a one-shot frame origin. No clock-pair cut.
set_max_delay -datapath_only -from [get_clocks {clocks/master.clkc[0]}] -through [get_nets {station/station/core/spectrum_bridge/ownership/held[*]}] -to [get_clocks {clocks/video.clkc[0]}] 13.000
set_false_path -to [get_regs {station/station/core/spectrum_bridge/ownership/req_meta}]
set_false_path -to [get_regs {station/station/core/spectrum_bridge/ownership/ack_meta}]
