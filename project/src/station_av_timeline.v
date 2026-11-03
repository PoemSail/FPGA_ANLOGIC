`timescale 1ns/1ps
// Adapted from reviewed av_content_clock_r20:64-bit content PTS, retained surfaces.
// frame_pts is GLOBAL across clip loops. sample_taken is the real PCM FIFO pop,
// synchronous to the SAME physical sample_tick; never use delayed audio_valid.
module station_av_timeline #(
 parameter integer SAMPLES_PER_FRAME=2000,MAX_VIDEO_LAG_SAMPLES=807,EARLY_VIDEO_SAMPLES=0
)(input wire clk,rst_n,paused,frame_boundary,swap_safe,
 input wire [11:0] samples_per_frame_in,
  input wire prebuffer_ready,pcm_available,sample_tick,sample_taken,
 input wire frame_pending,frame_slot,input wire [63:0] frame_pts,
 output wire play_enable,publish,rebuffering,
 output reg display_valid,display_slot,output reg [63:0] display_pts,
 output wire release_valid,output wire release_slot,
 output reg [63:0] content_samples,output reg [31:0] audio_starves,video_stalls,output reg fault
);
 localparam PRIME=0,RUN=1,BUFFER=2,FAILED=3;
 reg [1:0] state;reg [63:0] next_frame_pts;
 wire [11:0] eff_samples_per_frame = (samples_per_frame_in == 12'd800) ? 12'd800 : SAMPLES_PER_FRAME;
 wire [11:0] eff_max_lag = (samples_per_frame_in == 12'd800) ? 12'd320 : MAX_VIDEO_LAG_SAMPLES;
 wire bad_pts=frame_pending&&frame_pts!=next_frame_pts;
 wire late=content_samples>=next_frame_pts&&content_samples-next_frame_pts>={4'd0,eff_max_lag};
 // A retained front plus queued next frame can occupy both surfaces. BUFFER
 // must not wait for a second full prefill before publishing/freeing the front.
 wire ready_to_resume=pcm_available&&(state==PRIME?prebuffer_ready:1'b1);
 // Default0 preserves the original never-early contract. A configured
 // nearest-refresh window may release the old surface before its late edge.
 // Guard subtraction by ordering; do not wrap a64-bit content clock addition.
 wire frame_due=content_samples>=frame_pts ||
  (EARLY_VIDEO_SAMPLES>0 && frame_pts>content_samples &&
   frame_pts-content_samples<=EARLY_VIDEO_SAMPLES);
 wire candidate=frame_pending&&!bad_pts&&frame_due;
 assign play_enable=rst_n&&!fault&&!bad_pts&&state==RUN&&!paused&&pcm_available&&!late;
 wire illegal_pop=sample_taken&&(!play_enable||!sample_tick);
 assign publish=rst_n&&!fault&&!paused&&!illegal_pop&&frame_boundary&&swap_safe&&candidate&&
  (state==RUN||((state==PRIME||state==BUFFER)&&ready_to_resume));
 assign rebuffering=rst_n&&(state==PRIME||state==BUFFER);
 assign release_valid=publish&&display_valid;
 assign release_slot=display_slot;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=PRIME;next_frame_pts<=0;content_samples<=0;audio_starves<=0;video_stalls<=0;fault<=0;
   display_valid<=0;display_slot<=0;display_pts<=0;
  end else if(illegal_pop||bad_pts)begin fault<=1;state<=FAILED;end
  else begin
   if(sample_taken)content_samples<=content_samples+1'b1;
   if(publish)begin
    display_valid<=1;display_slot<=frame_slot;display_pts<=frame_pts;
    next_frame_pts<=frame_pts+{52'd0,eff_samples_per_frame};
   end
   case(state)
    PRIME:if(publish)state<=RUN;
    RUN:if(!paused)begin
     if(sample_tick&&!pcm_available)begin
      state<=BUFFER;if(audio_starves!=32'hffffffff)audio_starves<=audio_starves+1'b1;
     end else if(late&&!publish)begin
      state<=BUFFER;if(video_stalls!=32'hffffffff)video_stalls<=video_stalls+1'b1;
     end
    end
    // Audio-only starvation recovery does not require a video surface swap.
    // Waiting a whole raster frame here can hold an already full FIFO silent.
    // A video-lag stop still requires a safe frame publication before resuming.
    BUFFER:if(!paused&&ready_to_resume&&((display_valid&&!late)||(frame_boundary&&swap_safe&&publish)))state<=RUN;
    FAILED:;
    default:begin fault<=1;state<=FAILED;end
   endcase
  end
 end
endmodule
