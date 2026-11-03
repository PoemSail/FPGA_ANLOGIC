// Parent SHA256 9e2993ec12ffdb90bea1c7c9a22a73eafa93331bd17e0919a293b8ffbba8f1ef
`timescale 1ns/1ps
// Compact serial CRC7 and 48-bit response tail; no SD cycle changes.
// Native read-only SDHC, default 1-bit; CMD17/CMD18, validated CRC quarantine.
// 50MHz fabric: init HALF=64 (390625Hz), data HALF=2 (12.5MHz).
// CMD launches on falling SDCLK, CMD/DAT sample after a complete low phase.
// A sector is quarantined until response and CRC16 on each active lane validate.
module sdhc_native_r12 #(
 parameter integer POWER_WAIT_CYCLES=500000,INIT_TIMEOUT_CYCLES=100000000,
 TOKEN_TIMEOUT_CYCLES=5000000,
 parameter integer INIT_HALF_PERIOD=64,DATA_HALF_PERIOD=2,BUS_WIDTH=1
)(
 input wire fast_stream,input wire [7:0] read_count,
 input wire clk,rst_n,retry_valid,output wire retry_ready,
 output reg initialized,output wire busy,output reg [3:0] error_code,
 input wire read_valid,output wire read_ready,input wire [31:0] read_lba,
 output wire data_valid,input wire data_ready,output reg [7:0] data,
 output wire data_last,output wire done_valid,input wire done_ready,output reg done_error,
 output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat
);
 localparam POWER=0,CLOCKS=1,LAUNCH=2,TX=3,RESP_START=4,RESP=5,CHECK=6,
  SELECT_BUSY=7,IDLE=8,READ_WAIT=9,FETCH=10,STREAM=11,RESULT=12,FAILED=13,GAP=14,CLOCK_SWITCH=15;
 reg [3:0] state;reg [3:0] step;reg [15:0] card_rca;
 // Reachable counters include the timeout threshold before failure/idle.
 localparam POWER_BITS=POWER_WAIT_CYCLES<2 ? 1 : $clog2(POWER_WAIT_CYCLES);
 localparam TOKEN_BITS=TOKEN_TIMEOUT_CYCLES<2 ? 1 : $clog2(TOKEN_TIMEOUT_CYCLES+1);
 localparam INIT_BITS=INIT_TIMEOUT_CYCLES<2 ? 1 : $clog2(INIT_TIMEOUT_CYCLES+1);
 localparam IS_50M = (DATA_HALF_PERIOD == 0);
 localparam EFF_DATA_HALF = IS_50M ? 1 : DATA_HALF_PERIOD;
 localparam MAX_HALF=INIT_HALF_PERIOD>EFF_DATA_HALF ? INIT_HALF_PERIOD : EFF_DATA_HALF;
 localparam DIV_BITS=MAX_HALF<2 ? 1 : $clog2(MAX_HALF);
 reg [POWER_BITS-1:0] power_count;reg [TOKEN_BITS-1:0] timeout_count;
 reg [INIT_BITS-1:0] init_count;reg [DIV_BITS-1:0] divider;
 // Actual SD rising edges, independent of core/SD divider ratios.
 reg [3:0] command_guard;
 // Keep the divider mode stable until the last high phase has completed.
 reg clock_data_mode;reg restart_pending;
 reg [6:0] idle_clocks;reg [5:0] command;
 reg [38:0] tx_header;reg [6:0] tx_crc;reg [7:0] bit_count,response_bits;
 reg cmd_oe,cmd_out;reg [47:0] response;reg response_transmission;reg [6:0] response_crc_running;
 reg burst_active,stop_pending;reg [7:0] burst_left;reg [31:0] expected_lba;
 reg read_pending;reg [2:0] rx_state;reg [12:0] nibble_count;reg [4:0] crc_count;
 reg [15:0] crc0,crc1,crc2,crc3;reg [15:0] got0,got1,got2,got3;
 reg [7:0] serial_byte;reg [3:0] high_nibble;reg rx_bad;reg [7:0] sector[0:511];reg [8:0] out_index;
 wire [15:0] half_period=clock_data_mode ? EFF_DATA_HALF : INIT_HALF_PERIOD;
 // Stop only in a full low phase between validated blocks; no short SD pulses.
 wire pause_clock=burst_active&&(state==FETCH||state==STREAM||state==RESULT||state==IDLE);
 reg sd_clk_reg;
 wire data_50m_active = IS_50M && clock_data_mode;
 wire tick=data_50m_active ? !pause_clock : ((divider==half_period-1)&&(!pause_clock||sd_clk_reg));
 wire rx_enable=read_pending&&!stop_pending;
 wire rise=data_50m_active ? !pause_clock : (tick&&!sd_clk_reg);
 wire fall=data_50m_active ? !pause_clock : (tick&&sd_clk_reg);
 // In 50MHz mode, capture at posedge clk (10ns after card launched on inverted clock rise).
 // In 25MHz mode (DATA_HALF_PERIOD==1), receive on fall.
 // Initialization and DATA_HALF_PERIOD>=2 retain the original rising CE.
 wire sample_tick=data_50m_active ? !pause_clock : ((clock_data_mode&&DATA_HALF_PERIOD==1)?fall:rise);

 wire oddr_d0 = data_50m_active ? 1'b0 : sd_clk_reg;
 wire oddr_d1 = data_50m_active ? !pause_clock : sd_clk_reg;

`ifdef SIMULATION
 reg oddr_q;
 always @(posedge clk or negedge rst_n) if(!rst_n) oddr_q <= 1'b0; else oddr_q <= oddr_d0;
 always @(negedge clk or negedge rst_n) if(!rst_n) oddr_q <= 1'b0; else oddr_q <= oddr_d1;
 assign sd_clk = oddr_q;
`else
 EG_LOGIC_ODDR #(.ASYNCRST("ENABLE")) sd_clk_forward(
  .q(sd_clk),.clk(clk),.d0(oddr_d0),.d1(oddr_d1),.rst(!rst_n)
 );
`endif

 assign sd_cmd=cmd_oe ? cmd_out:1'bz;
 assign sd_dat=4'bzzzz;
 assign retry_ready=rst_n&&!restart_pending&&(state==FAILED||state==IDLE);
 assign read_ready=rst_n&&initialized&&!restart_pending&&state==IDLE;
 assign busy=restart_pending||(state!=IDLE&&state!=FAILED);
 assign data_valid=rst_n&&state==STREAM;
 assign data_last=data_valid&&out_index==511;
 assign done_valid=rst_n&&state==RESULT;
 function [6:0] crc7bit;
  input [6:0] c;input b;
  begin crc7bit={c[5:0],1'b0}^((c[6]^b)?7'h09:7'h00);end
 endfunction
 function [15:0] crc16bit;
  input [15:0] c;input b;
  begin crc16bit={c[14:0],1'b0}^((c[15]^b) ? 16'h1021:16'h0000);end
 endfunction
 task issue;
  input [5:0] cmd;input [31:0] arg;input [3:0] next_step;
  begin command<=cmd;tx_header<={1'b1,cmd,arg};step<=next_step;state<=LAUNCH;timeout_count<=0;end
 endtask
 task fail_init;
  input [3:0] code;begin initialized<=0;error_code<=code;cmd_oe<=0;state<=FAILED;end
 endtask
 wire sector_read_enable=(state==FETCH)||(fast_stream&&state==STREAM&&data_ready&&out_index!=511);
 wire [8:0] sector_read_address=(state==FETCH)?out_index:out_index+1'b1;
 always @(posedge clk)begin
  if(sector_read_enable)data<=sector[sector_read_address];
  if(rst_n&&rx_enable&&sample_tick&&rx_state==1)begin
   if(BUS_WIDTH==1)begin
    if(nibble_count[2:0]==7)sector[nibble_count[11:3]]<={serial_byte[6:0],sd_dat[0]};
   end else if(nibble_count[0])sector[nibble_count[10:1]]<={high_nibble,sd_dat};
  end
 end
 wire [3:0] lane_errors=BUS_WIDTH==1?{3'b0,got0!=crc0}:{got3!=crc3,got2!=crc2,got1!=crc1,got0!=crc0};
 // Receive data independently of command response; earliest legal data is not lost.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin rx_state<=0;nibble_count<=0;crc_count<=0;high_nibble<=0;serial_byte<=0;
   crc0<=0;crc1<=0;crc2<=0;crc3<=0;got0<=0;got1<=0;got2<=0;got3<=0;rx_bad<=0;end
  else if(!rx_enable)begin rx_state<=0;rx_bad<=0;nibble_count<=0;crc_count<=0;
   crc0<=0;crc1<=0;crc2<=0;crc3<=0;got0<=0;got1<=0;got2<=0;got3<=0;end
  else if(sample_tick)case(rx_state)
   0:if(BUS_WIDTH==1?sd_dat[0]!==1'b1:sd_dat!==4'hf)begin
    if(BUS_WIDTH==1?sd_dat[0]!==1'b0:sd_dat!==4'h0)begin rx_bad<=1;rx_state<=4;end else rx_state<=1;end
   1:begin high_nibble<=sd_dat;serial_byte<={serial_byte[6:0],sd_dat[0]};nibble_count<=nibble_count+1'b1;
    crc0<=crc16bit(crc0,sd_dat[0]);crc1<=crc16bit(crc1,sd_dat[1]);
    crc2<=crc16bit(crc2,sd_dat[2]);crc3<=crc16bit(crc3,sd_dat[3]);
    if(nibble_count==(BUS_WIDTH==1?4095:1023))begin crc_count<=0;rx_state<=2;end end
   2:begin got0<={got0[14:0],sd_dat[0]};got1<={got1[14:0],sd_dat[1]};
    got2<={got2[14:0],sd_dat[2]};got3<={got3[14:0],sd_dat[3]};
    if(crc_count==15)rx_state<=3;else crc_count<=crc_count+1'b1;end
   3:begin rx_bad<=(BUS_WIDTH==1?sd_dat[0]!==1'b1:sd_dat!==4'hf)||(|lane_errors);rx_state<=4;end
  endcase
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   burst_active<=0;stop_pending<=0;burst_left<=0;expected_lba<=0;
   state<=POWER;step<=0;power_count<=0;timeout_count<=0;init_count<=0;divider<=0;sd_clk_reg<=0;
   restart_pending<=0;clock_data_mode<=0;command_guard<=0;idle_clocks<=0;command<=0;tx_header<=0;tx_crc<=0;bit_count<=0;response_bits<=48;
   cmd_oe<=0;cmd_out<=1;response<=0;response_transmission<=0;response_crc_running<=0;read_pending<=0;initialized<=0;error_code<=0;
   card_rca<=0;out_index<=0;done_error<=0;
  end else begin
   if(state==POWER)begin divider<=0;sd_clk_reg<=0;end
   else if(pause_clock&&!sd_clk_reg)divider<=0;
   else if(tick)begin divider<=0;sd_clk_reg<=!sd_clk_reg;end else divider<=divider+1'b1;
   if(!initialized&&state!=FAILED)init_count<=init_count+1'b1;
   if(state==RESP_START||state==RESP||state==READ_WAIT||state==SELECT_BUSY)timeout_count<=timeout_count+1'b1;
   if(rise&&command_guard!=0)command_guard<=command_guard-1'b1;
   if(!restart_pending)case(state)
    POWER:if(power_count==POWER_WAIT_CYCLES-1)begin power_count<=0;idle_clocks<=0;state<=CLOCKS;end else power_count<=power_count+1'b1;
    CLOCKS:if(fall)begin if(idle_clocks==79)issue(0,0,0);else idle_clocks<=idle_clocks+1'b1;end
    LAUNCH:if(fall&&command_guard==0)begin
     // issue preloads header before LAUNCH; omit duplicate argument bank.
     tx_crc<=0;
     cmd_oe<=1;cmd_out<=0;bit_count<=47;state<=TX;
    end
    TX:if(fall)begin
     if(bit_count==0)begin command_guard<=8;cmd_oe<=0;response<=0;timeout_count<=0;
      if(command==0)begin idle_clocks<=0;state<=GAP;end
      else begin response_bits<=command==2 ? 136:48;state<=RESP_START;end
     end else begin
      // Launch already emitted start=0. Header bits38..0, CRC6..0, end=1
      // occupy the same 47 following falling edges as the original shifter.
      if(bit_count>8)begin
       cmd_out<=tx_header[38];tx_crc<=crc7bit(tx_crc,tx_header[38]);
       tx_header<={tx_header[37:0],1'b1};
      end else if(bit_count>1)begin cmd_out<=tx_crc[6];tx_crc<={tx_crc[5:0],1'b0};end
      else cmd_out<=1'b1;
      bit_count<=bit_count-1'b1;
     end
    end
    GAP:if(fall)begin if(idle_clocks==7)issue(8,32'h1aa,1);else idle_clocks<=idle_clocks+1'b1;end
    RESP_START:if(sample_tick&&sd_cmd===1'b0)begin response_crc_running<=0;response<=0;bit_count<=response_bits-1'b1;state<=RESP;end
    RESP:if(sample_tick)begin response<={response[46:0],sd_cmd};
     if(bit_count==response_bits-1'b1)response_transmission<=sd_cmd;
     // bit_count-1 is the bit currently sampled. R2 excludes header[135:128].
     // Both forms exclude received CRC[7:1] and end[0]; the first start bit is 0.
     if(bit_count>8&&(response_bits==48||bit_count<=128))
      response_crc_running<=crc7bit(response_crc_running,sd_cmd);
     if(bit_count==1)begin command_guard<=8;state<=CHECK;end else bit_count<=bit_count-1'b1;end
    CHECK:begin
     if(response[0]!==1'b1||response_transmission!==1'b0)
      begin if(read_pending)begin done_error<=1;error_code<=3;read_pending<=0;state<=RESULT;end else fail_init(3);end
     else if(command!=41&&response[7:1]!=response_crc_running)
      begin if(read_pending)begin done_error<=1;error_code<=4;read_pending<=0;state<=RESULT;end else fail_init(4);end
     else if(command!=2&&command!=41&&response[45:40]!=command)
      begin if(read_pending)begin done_error<=1;error_code<=3;read_pending<=0;state<=RESULT;end else fail_init(3);end
     else case(step)
      1:if(response[39:8]!=32'h1aa)fail_init(5);else issue(55,0,2);
      2:if((response[39:8]&32'hfff9a008)!=0||!response[13])fail_init(6);else issue(41,32'h40ff8000,3);
      3:begin
       if(!response[39])issue(55,0,2);else if(!response[38]||(response[39:8]&32'h00ff8000)==0)fail_init(5);else issue(2,0,4);end
      4:issue(3,0,5);
      5:if(response[39:24]==0||(response[23:8]&16'he000)!=0)fail_init(6);
       else begin card_rca<=response[39:24];issue(7,{response[39:24],16'b0},6);end
      6:if((response[39:8]&32'hfff9a008)!=0)fail_init(6);else begin state<=SELECT_BUSY;timeout_count<=0;end
      7:if((response[39:8]&32'hfff9a008)!=0||!response[13])fail_init(6);else issue(6,BUS_WIDTH==1?0:2,8);
      8:begin if((response[39:8]&32'hfff9a008)!=0)fail_init(6);else begin state<=CLOCK_SWITCH;end end
      10:if((response[39:8]&32'hfff9a008)!=0)begin done_error<=1;error_code<=6;read_pending<=0;burst_active<=0;state<=RESULT;end
       else begin state<=SELECT_BUSY;timeout_count<=0;end
      9:if((response[39:8]&32'hfff9a008)!=0)begin done_error<=1;error_code<=6;read_pending<=0;state<=RESULT;end else state<=READ_WAIT;
      default:fail_init(6);
     endcase
    end
    // Commit the new divisor at the end of a full initialization-clock high phase.
    // The normal clock block resets divider and drives SDCLK low on this edge.
    // Do not reset SDCLK mid-phase or let CHECK latency determine the handoff.
    CLOCK_SWITCH:if(fall)begin clock_data_mode<=1;initialized<=1;state<=IDLE;error_code<=0;end
    SELECT_BUSY:if(sample_tick&&sd_dat[0]===1'b1)begin
     if(step==10)begin burst_active<=0;stop_pending<=0;read_pending<=0;out_index<=0;state<=FETCH;end
     else issue(55,{card_rca,16'b0},7);
    end
    IDLE:if(read_valid)begin
     read_pending<=1;done_error<=0;error_code<=0;timeout_count<=0;
     if(burst_active)begin
      if(read_lba!=expected_lba)begin done_error<=1;error_code<=6;read_pending<=0;burst_active<=0;state<=RESULT;end
      else begin expected_lba<=expected_lba+1'b1;state<=READ_WAIT;end
     end else if(fast_stream&&read_count>1)begin
      burst_active<=1;burst_left<=read_count;expected_lba<=read_lba+1'b1;issue(18,read_lba,9);
     end else issue(17,read_lba,9);
    end
    READ_WAIT:if(rx_state==4)begin
     if(rx_bad)begin read_pending<=0;burst_active<=0;done_error<=1;error_code<=7;state<=RESULT;end
     else if(burst_active&&burst_left==1)begin stop_pending<=1;issue(12,0,10);end
     else begin
      read_pending<=0;out_index<=0;state<=FETCH;
      if(burst_active)burst_left<=burst_left-1'b1;
     end
    end
    FETCH:state<=STREAM;
    STREAM:if(data_ready)begin if(out_index==511)state<=RESULT;else begin out_index<=out_index+1'b1;state<=fast_stream ? STREAM:FETCH;end end
    // An errored card may still be transmitting its old sector. Require CMD0
    // reinitialization instead of advertising read_ready for a second CMD17.
    RESULT:begin if(done_error)burst_active<=0; if(done_ready)begin
     if(done_error)begin initialized<=0;cmd_oe<=0;state<=FAILED;end
     else state<=IDLE;
    end end
    FAILED:begin end // Clock drains a card packet; new reads remain blocked.
   endcase
   if(!restart_pending&&timeout_count>=TOKEN_TIMEOUT_CYCLES&&(state==RESP_START||state==RESP||state==READ_WAIT||state==SELECT_BUSY))begin
    cmd_oe<=0;read_pending<=0;burst_active<=0;stop_pending<=0;
    if(initialized)begin done_error<=1;error_code<=2;state<=RESULT;end else fail_init(2);
   end
   if(!restart_pending&&!initialized&&init_count>=INIT_TIMEOUT_CYCLES&&state!=FAILED)fail_init(1);
   if(retry_valid&&retry_ready)begin burst_active<=0;stop_pending<=0;restart_pending<=1;initialized<=0;read_pending<=0;cmd_oe<=0;end
   // Acknowledge retry now, stop/reset divider only at a complete high phase.
   if(restart_pending&&fall)begin restart_pending<=0;clock_data_mode<=0;command_guard<=0;
    initialized<=0;read_pending<=0;state<=POWER;power_count<=0;init_count<=0;timeout_count<=0;
    error_code<=0;cmd_oe<=0;end
  end
 end
endmodule
