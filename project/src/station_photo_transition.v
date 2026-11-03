`timescale 1ns/1ps
// Two-source BL8 photo transition control, for480-pixel/240-word rows.
// No extra line cache: each aligned8-word burst is read from old or candidate.
// mode0=cut; mode1=horizontal wipe,30 frame intervals; mode2=vertical blinds,
// 64-source-pixel stripes,16-pixel steps held8 frames (32 intervals).
// Caller owns BOTH surfaces until commit_candidate in a drained window.
module station_photo_transition(
 input wire clk,rst_n,frame_tick,swap_safe,line_idle,
 input wire start_valid,output wire start_ready,input wire [1:0] start_mode,
 input wire finish_request,input wire [7:0] relative_word,
 output wire choose_candidate,commit_candidate,
 output reg active,done,fault,output reg [1:0] mode,output reg [7:0] phase
);
 reg [2:0] hold_frames;
 wire window=frame_tick&&swap_safe&&line_idle&&!fault;
 wire take=start_valid&&start_ready;
 wire last_step=mode==1?phase>=232:(phase>=3&&hold_frames==7);
 assign start_ready=rst_n&&!active&&window;
 // Combinational same-window commit lets owner change slot/generation on
 // THIS edge, before the existing bridge captures its held descriptor.
 // done is only a registered diagnostic pulse, not an ownership handshake.
 assign commit_candidate=rst_n&&!fault&&((take&&start_mode==0)||(active&&window&&(finish_request||last_step)));
 assign choose_candidate=!active?1'b1:mode==1?(relative_word<phase):
  (phase>=4||{6'b0,relative_word[4:3]}<phase);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin active<=0;done<=0;fault<=0;mode<=0;phase<=0;hold_frames<=0;end
  else begin
   done<=0;
   if(take)begin
    mode<=start_mode;phase<=0;hold_frames<=0;
    if(start_mode==3)fault<=1;
    else if(start_mode==0)begin active<=0;done<=1;end
    else active<=1;
   end else if(active&&window)begin
    if(finish_request||last_step)begin active<=0;done<=1;phase<=mode==1?240:4;hold_frames<=0;end
    else if(mode==1)phase<=phase+8'd8;
    else if(hold_frames==7)begin phase<=phase+1'b1;hold_frames<=0;end
    else hold_frames<=hold_frames+1'b1;
   end
  end
 end
endmodule
