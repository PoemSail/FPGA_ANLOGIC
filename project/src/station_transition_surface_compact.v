`timescale 1ns/1ps
// Photo ownership across a two-surface transition. The OLD token remains live
// until same-window commit; scheduler must wait for front slot/generation.
// Candidate fields enter the display tag only while mixing, preventing a
// mid-frame descriptor acceptance from invalidating the existing row tags.
module station_transition_surface_compact #(
 parameter [20:0] PHOTO_BASE0=21'h40000,PHOTO_BASE1=21'h52000
)(
 input wire clk,rst_n,frame_boundary,pixel_swap_safe,line_idle,
 input wire request_photo,effect_enable,memory_fault,input wire [1:0] transition_mode,
 input wire descriptor_valid,output wire descriptor_ready,input wire descriptor_error,
 input wire [20:0] descriptor_base,input wire descriptor_slot,input wire [15:0] descriptor_generation,
 output reg release_valid,release_slot,output reg [15:0] release_generation,
 input wire video_valid,video_slot,video_publish,input wire [63:0] video_pts,
 input wire [15:0] video_width,video_height,
 output wire display_valid,output wire [20:0] display_base,candidate_base,output wire [63:0] display_pts,
 output wire [15:0] display_width,display_height,output wire publish,
 output reg selected_photo,front_valid,front_slot,output reg [15:0] front_generation,
 output reg pending_valid,load_error,output wire fault,
 output wire mix_enable,output wire [1:0] mix_mode,output wire [7:0] mix_phase
);
 reg pending_slot,owner_fault;reg [15:0] pending_generation;reg [1:0] pending_mode;
 wire effect_fault,start_ready,commit_candidate;
 wire window=frame_boundary&&pixel_swap_safe&&line_idle&&!fault&&!memory_fault;
 wire accept=descriptor_valid&&descriptor_ready;
 wire descriptor_ok=descriptor_generation!=0&&transition_mode<=2&&
  descriptor_base==(descriptor_slot?PHOTO_BASE1:PHOTO_BASE0)&&!(front_valid&&descriptor_slot==front_slot);
 wire [1:0] start_mode=(front_valid&&selected_photo&&request_photo&&effect_enable)?pending_mode:2'd0;
 assign fault=owner_fault||effect_fault;
 assign descriptor_ready=rst_n&&!pending_valid&&!fault&&!memory_fault;
 assign publish=rst_n&&((window&&(request_photo!=selected_photo||pending_valid||mix_enable))||(!selected_photo&&video_publish));
 assign display_valid=rst_n&&!fault&&!memory_fault&&(selected_photo?front_valid:video_valid);
 assign display_base=selected_photo?(front_slot?PHOTO_BASE1:PHOTO_BASE0):(video_slot?21'h12000:21'd0);
 assign candidate_base=pending_slot?PHOTO_BASE1:PHOTO_BASE0;
 // Two slots: candidate is always the non-front slot, validated above.
 // Candidate cannot change while pending/mixing. Old16-bit generation plus
 // slot, active and5-bit step uniquely identify this transition until commit.
 // Full pending16-bit generation is retained for scheduler/release ownership.
 wire [4:0] tag_step=mix_mode==1?mix_phase[7:3]:{2'b0,mix_phase[2:0]};
 assign display_pts=selected_photo?{41'd0,front_generation,front_slot,mix_enable,(mix_enable?tag_step:5'd0)}:video_pts;
 assign display_width=selected_photo?16'd480:video_width;
 assign display_height=selected_photo?16'd270:video_height;
 station_photo_transition transition(.clk(clk),.rst_n(rst_n),.frame_tick(window),.swap_safe(1'b1),.line_idle(1'b1),
  .start_valid(pending_valid),.start_ready(start_ready),.start_mode(start_mode),
  .finish_request(!request_photo||!effect_enable),.relative_word(8'd0),.choose_candidate(),
  .commit_candidate(commit_candidate),.active(mix_enable),.done(),.fault(effect_fault),.mode(mix_mode),.phase(mix_phase));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   release_valid<=0;release_slot<=0;release_generation<=0;selected_photo<=0;
   front_valid<=0;front_slot<=0;front_generation<=0;pending_valid<=0;
   pending_slot<=0;pending_generation<=0;pending_mode<=0;load_error<=0;owner_fault<=0;
  end else begin
   release_valid<=0;load_error<=0;
   if(memory_fault)owner_fault<=1;
   if(accept)begin
    if(descriptor_error)load_error<=1;
    else if(!descriptor_ok)owner_fault<=1;
    else begin pending_valid<=1;pending_slot<=descriptor_slot;pending_generation<=descriptor_generation;pending_mode<=transition_mode;end
   end
   if(window)begin
    selected_photo<=request_photo;
    if(commit_candidate)begin
     if(front_valid)begin release_valid<=1;release_slot<=front_slot;release_generation<=front_generation;end
     front_valid<=1;front_slot<=pending_slot;front_generation<=pending_generation;pending_valid<=0;
    end
   end
  end
 end
endmodule
