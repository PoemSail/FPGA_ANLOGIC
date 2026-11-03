// Independent coordinate-snapshot candidate; transaction interface unchanged.
// Same module name; choose one resampler. Synchronous cache adds hit latency.
`timescale 1ns/1ps
// Committed top-down RGB888 scratch -> complete RGB565 canvas stream.
// Two BL8 RAM-backed cache lines; one extra clock per hit. One SDRAM read outstanding.
// Backend: aligned32-bit word requests, exactly8 ordered unbackpressured beats.
// Cancellation/errors drain an accepted burst before reporting completion.
// Output pixels are candidates: caller must acknowledge all destination writes
// before publishing the resulting surface. Source ownership lasts until done.
module station_photo_resampler #(
 parameter [20:0] SOURCE_BASE=21'h80000
)(
 input wire clk,rst_n,start_valid,output wire start_ready,
 input wire [15:0] source_width,source_height,input wire cancel,
 output wire pixel_valid,input wire pixel_ready,
 output wire [17:0] pixel_address,output reg [15:0] pixel_rgb565,
 output wire done_valid,input wire done_ready,output reg [3:0] error_code,
 output wire memory_quiet,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,input wire memory_fault
);
 localparam IDLE=0,COORD=1,TOP_ADDR=2,BOTTOM_ADDR=3,SELECT=4,REQUEST=5,
  RECEIVE=6,BLEND=7,WAIT_BLEND=8,EMIT=9,DRAIN=10,REPORT=11,SAMPLE=12;
 reg [3:0] state;reg [15:0] sw;reg [1:0] neighbour;
 reg [21:0] row_top,row_bottom;reg [20:0] sample_address,burst_address;
 reg [2:0] beat;reg outstanding,replace_slot,fill_slot,valid0,valid1;
 reg [17:0] tag0,tag1;
 reg [23:0] p00,p10,p01,p11;
 wire cfg_ready,cv,inside_image,cd;wire [1:0] ce;
 wire [10:0] sx,sx1;wire [9:0] sy,sy1;wire [7:0] fx,fy;
 // COORD holds one transaction until EMIT accepts its destination pixel.
 // Snapshot all interpolation coordinates together, before address arithmetic.
 // The existing TOP/BOTTOM states remain the shared multiplication stages.
 reg [10:0] sample_sx,sample_sx1;reg [9:0] sample_sy,sample_sy1;
 reg [7:0] sample_fx,sample_fy;
 wire [17:0] ca;wire br,bv;wire [23:0] rgb;
 wire abort_now=cancel||error_code!=0||memory_fault;
 wire take=pixel_valid&&pixel_ready;
 assign start_ready=rst_n&&!abort_now&&state==IDLE&&cfg_ready;
 assign pixel_valid=rst_n&&!abort_now&&state==EMIT;
 assign pixel_address=ca;
 assign done_valid=rst_n&&state==REPORT;
 assign rd_valid=rst_n&&!abort_now&&state==REQUEST;
 assign rd_address=burst_address;
 assign memory_quiet=rst_n&&!outstanding&&!rd_valid;
 station_photo_coordinates coordinates(.clk(clk),.rst_n(rst_n),
  .cfg_valid(start_valid&&start_ready),.cfg_ready(cfg_ready),.source_width(source_width),.source_height(source_height),
  .cancel(abort_now),.out_valid(cv),.out_ready(take),.x(),.y(),.address(ca),
  .inside_image(inside_image),.sx(sx),.sx1(sx1),.sy(sy),.sy1(sy1),.fraction_x(fx),.fraction_y(fy),
  .fitted_width(),.fitted_height(),.left(),.upper(),.done_valid(cd),.done_ready(state==REPORT&&done_ready),.error_code(ce));
 station_bilinear_pixel blend(.clk(clk),.rst_n(rst_n&&!abort_now),
  .in_valid(state==BLEND),.in_ready(br),.p00(p00),.p10(p10),.p01(p01),.p11(p11),
  .fraction_x(sample_fx),.fraction_y(sample_fy),.out_valid(bv),.out_ready(state==WAIT_BLEND),.rgb(rgb));
 // Shared row product, one multiplication stage reused for the two rows.
 wire [9:0] selected_y=state==TOP_ADDR?sample_sy:sample_sy1;
 wire [20:0] row_product=selected_y*sw[10:0];
 wire [21:0] next_address=(neighbour[1]?row_bottom:row_top)+
  (neighbour[0]?{11'd0,sample_sx1}:{11'd0,sample_sx});
 wire hit0=valid0&&tag0==next_address[20:3];
 wire hit1=valid1&&tag1==next_address[20:3];
 wire [23:0] sample_rgb;
 station_photo_cache32k cache(
  .clk(clk),.read_enable(rst_n&&state==SELECT&&(hit0||hit1)&&!next_address[21]),
  .read_address({!hit0,next_address[2:0]}),.read_data(sample_rgb),
  .write_enable(rst_n&&state==RECEIVE&&rd_data_valid),
  .write_address({fill_slot,beat}),.write_data(rd_data[23:0]));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   sample_sx<=0;sample_sx1<=0;sample_sy<=0;sample_sy1<=0;sample_fx<=0;sample_fy<=0;
   state<=IDLE;sw<=0;neighbour<=0;row_top<=0;row_bottom<=0;sample_address<=0;burst_address<=0;
   beat<=0;outstanding<=0;replace_slot<=0;fill_slot<=0;valid0<=0;valid1<=0;tag0<=0;tag1<=0;
   p00<=0;p10<=0;p01<=0;p11<=0;pixel_rgb565<=0;error_code<=0;
  end else begin
   case(state)
    IDLE:if(start_valid&&start_ready)begin
     state<=COORD;sw<=source_width;valid0<=0;valid1<=0;replace_slot<=0;error_code<=0;
    end
    COORD:begin
     if(cv)begin
      sample_sx<=sx;sample_sx1<=sx1;sample_sy<=sy;sample_sy1<=sy1;
      sample_fx<=fx;sample_fy<=fy;
     end
     if(cd)begin if(ce!=0)error_code<=1;state<=REPORT;end
     else if(cv)begin
      if(!inside_image)begin pixel_rgb565<=0;state<=EMIT;end
      else begin neighbour<=0;state<=TOP_ADDR;end
     end
    end
    TOP_ADDR:begin row_top<={1'b0,SOURCE_BASE}+{1'b0,row_product};state<=BOTTOM_ADDR;end
    BOTTOM_ADDR:begin row_bottom<={1'b0,SOURCE_BASE}+{1'b0,row_product};state<=SELECT;end
    SELECT:begin
     if(next_address[21])begin error_code<=4;state<=DRAIN;end
     else if(hit0||hit1)state<=SAMPLE; else begin
      sample_address<=next_address[20:0];burst_address<={next_address[20:3],3'b000};
      fill_slot<=!valid0?0:!valid1?1:replace_slot;state<=REQUEST;
     end
    end
    SAMPLE:begin
     case(neighbour)0:p00<=sample_rgb;1:p10<=sample_rgb;2:p01<=sample_rgb;3:p11<=sample_rgb;endcase
     if(neighbour==3)state<=BLEND;else begin neighbour<=neighbour+1'b1;state<=SELECT;end
    end
    REQUEST:if(rd_valid&&rd_ready)begin outstanding<=1;beat<=0;state<=RECEIVE;end
    RECEIVE:if(rd_data_valid)begin
     if(rd_last!=(beat==7)&&error_code==0)error_code<=3;
     if(beat==7)begin
      outstanding<=0;
      if(fill_slot)begin valid1<=1;tag1<=sample_address[20:3];end
      else begin valid0<=1;tag0<=sample_address[20:3];end
      replace_slot<=!fill_slot;
      state<=abort_now||rd_last!=1'b1 ? DRAIN:SELECT;
     end else beat<=beat+1'b1;
    end
    BLEND:if(br)state<=WAIT_BLEND;
    WAIT_BLEND:if(bv)begin pixel_rgb565<={rgb[23:19],rgb[15:10],rgb[7:3]};state<=EMIT;end
    EMIT:if(pixel_ready)state<=COORD;
    DRAIN:if(!outstanding&&cd)state<=REPORT;
    REPORT:if(done_ready)begin state<=IDLE;error_code<=0;valid0<=0;valid1<=0;end
    default:begin error_code<=3;state<=DRAIN;end
   endcase
   // Unexpected data is a protocol fault. Normal backend has no zero-latency
   // response in the request acceptance cycle. Drain length is fixed8 beats.
   if(rd_data_valid&&state!=RECEIVE&&state!=IDLE&&state!=REPORT)begin error_code<=3;state<=DRAIN;end
   if(state!=IDLE&&state!=REPORT&&abort_now)begin
    if(error_code==0)error_code<=cancel?2:5;
    if(state!=RECEIVE&&state!=DRAIN)state<=DRAIN;
   end
  end
 end
endmodule
