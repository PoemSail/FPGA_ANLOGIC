`timescale 1ns/1ps
// Synchronous BRAM FIFO; masked BL8 writes; physical acknowledgements.
module sdram_burst_controller #(
 parameter integer POWER_CYCLES=10000,REFRESH_CYCLES=150
)(
 input wire clk,rst_n,output reg initialized,input wire write_window,
 input wire wr_valid,output wire wr_ready,input wire [20 : 0] wr_address,input wire [31 : 0] wr_data,
 output wire wr_rsp_valid,input wire wr_rsp_ready,output wire wr_rsp_error,
 input wire rd_valid,output wire rd_ready,input wire [20 : 0] rd_address,
 output reg rd_data_valid,output reg [31 : 0] rd_data,output reg rd_last,
 output reg protocol_error,
 output wire sdram_clk,output reg sdram_ras_n,sdram_cas_n,sdram_we_n,
 output reg [10 : 0] sdram_addr,output reg [1 : 0] sdram_ba,
 output reg [3 : 0] sdram_dqm,inout wire [31 : 0] sdram_dq
);
 localparam POWER=0,PRE_INIT=1,REF_INIT=2,MODE=3,IDLE=4,PRE=5,ACT=6,ACCESS=7,
 READ_WAIT=8,READ_DATA=9,WRITE_WAIT=10,REFRESH=11,WAIT=12,INIT_DONE=13,WRITE_DATA=14;
 reg [3 : 0] state,next_state;reg [31 : 0] timer,refresh_timer;
 reg [3 : 0] init_refresh,beat;reg row_open,operation_write;
 reg [10 : 0] open_row;reg [1 : 0] open_bank;reg [20 : 0] address;
 reg dq_drive;reg [31 : 0] write_data;reg [3 : 0] responses;
 reg [52 : 0] queue[0 : 255];reg [52 : 0] head;
 reg [7 : 0] qwrite,qread;reg [8 : 0] qcount;
 reg [1 : 0] pack_state;reg [3 : 0] pack_count;reg [4 : 0] pack_wait;
 reg [20 : 0] pack_base,pack_last;reg [7 : 0] pack_mask;reg [31 : 0] pack_words[0 : 7];
 wire [20 : 0] head_address=head[52 : 32];
 wire append_ok=pack_count==0||(head_address==pack_last+1'b1&&head_address[20 : 3]==pack_base[20 : 3]);
 wire push=wr_valid&&wr_ready;
 wire pop=rst_n&&pack_state==2&&qcount!=0&&append_ok;
 wire write_complete=rst_n&&state==WRITE_WAIT;
 assign wr_ready=rst_n&&initialized&&qcount<256;
 assign wr_rsp_valid=rst_n&&responses!=0;assign wr_rsp_error=1'b0;
 assign sdram_clk=~clk;assign sdram_dq=dq_drive ? write_data : 32'bz;
 assign rd_ready=rst_n&&initialized&&state==IDLE&&refresh_timer<REFRESH_CYCLES;
 // Simple dual-port synchronous RAM, without array reset/combinational read.
 always @(posedge clk)begin
  if(push)queue[qwrite]<={wr_address,wr_data};head<=queue[qread];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin qwrite<=0;qread<=0;qcount<=0;end
  else begin
   if(push)qwrite<=qwrite+1'b1;if(pop)qread<=qread+1'b1;
   case({push,pop})2'b10 : qcount<=qcount+1'b1;2'b01 : qcount<=qcount-1'b1;default : ;endcase
  end
 end
 // Pack consecutive words in one aligned block. Mask partial/sparse tails.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin pack_state<=0;pack_count<=0;pack_wait<=0;pack_base<=0;pack_last<=0;pack_mask<=0;end
  else case(pack_state)
   0 : if(qcount!=0)begin pack_state<=1;pack_wait<=0;end
   1 : pack_state<=2;
   2 : if(qcount!=0)begin
    pack_wait<=0;
    if(append_ok)begin
     if(pack_count==0)pack_base<={head_address[20 : 3],3'b000};
     pack_words[head_address[2 : 0]]<=head[31 : 0];pack_mask[head_address[2 : 0]]<=1;
     pack_count<=pack_count+1'b1;pack_last<=head_address;
     pack_state<=head_address[2 : 0]==7 ? 3 : 1;
    end else pack_state<=3;
   end else if(pack_count==0)pack_state<=0;
   else if(pack_wait==15)pack_state<=3;else pack_wait<=pack_wait+1'b1;
   3 : if(write_complete)begin pack_state<=0;pack_count<=0;pack_mask<=0;pack_wait<=0;end
  endcase
 end
 task wait_cycles;
  input [31 : 0] cycles;input [3 : 0] target;
  begin timer<=cycles-1;next_state<=target;state<=WAIT;end
 endtask
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=POWER;next_state<=POWER;timer<=0;refresh_timer<=0;init_refresh<=0;
   initialized<=0;row_open<=0;open_row<=0;open_bank<=0;operation_write<=0;address<=0;
   write_data<=0;dq_drive<=0;responses<=0;rd_data_valid<=0;rd_data<=0;rd_last<=0;beat<=0;
   sdram_ras_n<=1;sdram_cas_n<=1;sdram_we_n<=1;sdram_addr<=0;sdram_ba<=0;sdram_dqm<=0;
   protocol_error<=0;
  end else begin
   sdram_ras_n<=1;sdram_cas_n<=1;sdram_we_n<=1;sdram_dqm<=0;dq_drive<=0;
   rd_data_valid<=0;rd_last<=0;
   if(wr_rsp_valid&&wr_rsp_ready)responses<=responses-1'b1;
   if(initialized&&refresh_timer!=32'hffffffff)refresh_timer<=refresh_timer+1'b1;
   case(state)
    POWER : if(timer==POWER_CYCLES-1)begin timer<=0;state<=PRE_INIT;end else timer<=timer+1'b1;
    PRE_INIT : begin sdram_ras_n<=0;sdram_we_n<=0;sdram_addr<=11'h400;wait_cycles(2,REF_INIT);end
    REF_INIT : begin sdram_ras_n<=0;sdram_cas_n<=0;init_refresh<=init_refresh+1'b1;wait_cycles(4,init_refresh==7 ? MODE : REF_INIT);end
    MODE : begin sdram_ras_n<=0;sdram_cas_n<=0;sdram_we_n<=0;sdram_ba<=0;sdram_addr<=11'h033;wait_cycles(2,INIT_DONE);end
    INIT_DONE : begin initialized<=1;refresh_timer<=0;state<=IDLE;end
    IDLE : if(refresh_timer>=REFRESH_CYCLES)begin
     if(row_open)begin sdram_ras_n<=0;sdram_we_n<=0;sdram_addr<=11'h400;row_open<=0;wait_cycles(2,REFRESH);end
     else state<=REFRESH;
    end else if(rd_valid||(write_window&&pack_state==3&&responses==0))begin
     address<=rd_valid ? rd_address : pack_base;operation_write<=!rd_valid;
     if(rd_valid&&rd_address[2 : 0]!=0)protocol_error<=1;
     if(row_open&&open_row==(rd_valid ? rd_address[20 : 10] : pack_base[20 : 10])&&open_bank==(rd_valid ? rd_address[9 : 8] : pack_base[9 : 8]))state<=ACCESS;
     else state<=row_open ? PRE : ACT;
    end
    PRE : begin sdram_ras_n<=0;sdram_we_n<=0;sdram_addr<=11'h400;row_open<=0;wait_cycles(2,ACT);end
    ACT : begin sdram_ras_n<=0;sdram_ba<=address[9 : 8];sdram_addr<=address[20 : 10];open_row<=address[20 : 10];open_bank<=address[9 : 8];row_open<=1;wait_cycles(2,ACCESS);end
    ACCESS : begin
     sdram_ba<=address[9 : 8];sdram_addr<={3'b000,address[7 : 0]};sdram_cas_n<=0;
     if(operation_write)begin
      sdram_we_n<=0;dq_drive<=1;write_data<=pack_words[0];sdram_dqm<=pack_mask[0] ? 4'b0000 : 4'b1111;
      beat<=1;state<=WRITE_DATA;
     end else begin timer<=2;state<=READ_WAIT;end
    end
    WRITE_DATA : begin
     dq_drive<=1;write_data<=pack_words[beat[2 : 0]];sdram_dqm<=pack_mask[beat[2 : 0]] ? 4'b0000 : 4'b1111;
     if(beat==7)wait_cycles(2,WRITE_WAIT);else beat<=beat+1'b1;
    end
    WRITE_WAIT : begin responses<=pack_count;state<=IDLE;end
    READ_WAIT : if(timer==0)begin rd_data<=sdram_dq;rd_data_valid<=1;beat<=1;state<=READ_DATA;end else timer<=timer-1'b1;
    READ_DATA : begin rd_data<=sdram_dq;rd_data_valid<=1;if(beat==7)begin rd_last<=1;state<=IDLE;end else beat<=beat+1'b1;end
    REFRESH : begin sdram_ras_n<=0;sdram_cas_n<=0;refresh_timer<=0;wait_cycles(4,IDLE);end
    WAIT : if(timer==0)state<=next_state;else timer<=timer-1'b1;
    default : state<=POWER;
   endcase
  end
 end
endmodule
