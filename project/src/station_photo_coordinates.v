`timescale 1ns/1ps
// Offline aspect-fit canvas walk. Reuses the existing restoring divider.
// Q16 DDA, endpoint aligned; Q8 fractions feed station_bilinear_pixel.
// Source is canonical top-down scratch. Bars require no source reads.
// One-pixel fitted axes sample source coordinate zero (not the far endpoint).
module station_photo_coordinates #(
 parameter integer WIDTH=480,HEIGHT=270
)(
 input wire clk,rst_n,cfg_valid,output wire cfg_ready,
 input wire [15:0] source_width,source_height,input wire cancel,
 output wire out_valid,input wire out_ready,
 output reg [9:0] x,output reg [8:0] y,output reg [17:0] address,
 output wire inside_image,output wire [10:0] sx,sx1,output wire [9:0] sy,sy1,
 output wire [7:0] fraction_x,fraction_y,
 output reg [15:0] fitted_width,fitted_height,left,upper,
 output wire done_valid,input wire done_ready,output reg [1:0] error_code
);
 localparam IDLE=0,FIT=1,WAIT_DIV=2,GEOMETRY=3,XDIV=4,YDIV=5,EMIT=6,DONE=7;
 reg [2:0] state;reg [1:0] operation;reg [15:0] sw,sh;reg wide;
 reg [31:0] step_x,step_y,phase_x,phase_y,numerator;
 reg [15:0] denominator;reg div_start;wire div_busy,div_done;wire [31:0] quotient;
 unsigned_divider divider(.clk(clk),.rst_n(rst_n&&!cancel),.start(div_start),
  .numerator(numerator),.denominator(denominator),.busy(div_busy),.done(div_done),.quotient(quotient));
 wire [31:0] by_height=sw*HEIGHT,by_width=sh*WIDTH;
 wire [15:0] ix={6'd0,x}-left,iy={7'd0,y}-upper;
 assign inside_image=x>=left&&x<left+fitted_width&&y>=upper&&y<upper+fitted_height;
 wire last_x=fitted_width>1&&ix==fitted_width-1'b1;
 wire last_y=fitted_height>1&&iy==fitted_height-1'b1;
 assign sx=!inside_image?0:last_x?sw-1'b1:phase_x[26:16];
 assign sy=!inside_image?0:last_y?sh-1'b1:phase_y[25:16];
 assign sx1=sx<sw-1'b1 ? sx+1'b1:sx;
 assign sy1=sy<sh-1'b1 ? sy+1'b1:sy;
 assign fraction_x=!inside_image||last_x?0:phase_x[15:8];
 assign fraction_y=!inside_image||last_y?0:phase_y[15:8];
 assign cfg_ready=rst_n&&!cancel&&state==IDLE&&!div_busy;
 assign out_valid=rst_n&&!cancel&&state==EMIT;
 assign done_valid=rst_n&&state==DONE;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;operation<=0;sw<=0;sh<=0;wide<=0;step_x<=0;step_y<=0;phase_x<=0;phase_y<=0;
   numerator<=0;denominator<=1;div_start<=0;x<=0;y<=0;address<=0;
   fitted_width<=0;fitted_height<=0;left<=0;upper<=0;error_code<=0;
  end else begin
   div_start<=0;
   case(state)
    IDLE:if(cfg_valid&&cfg_ready)begin
     sw<=source_width;sh<=source_height;error_code<=0;x<=0;y<=0;address<=0;phase_x<=0;phase_y<=0;
     if(source_width==0||source_width>1024||source_height==0||source_height>768||WIDTH<1||WIDTH>1024||HEIGHT<1||HEIGHT>512)begin
      error_code<=1;state<=DONE;
     end else state<=FIT;
    end
    FIT:begin
     wide<=by_height>=by_width;numerator<=by_height>=by_width?by_width:by_height;
     denominator<=by_height>=by_width?sw:sh;operation<=0;div_start<=1;state<=WAIT_DIV;
    end
    WAIT_DIV:if(div_done)case(operation)
     0:begin
      fitted_width<=wide?WIDTH:(quotient==0?1:quotient[15:0]);
      fitted_height<=wide?(quotient==0?1:quotient[15:0]):HEIGHT;state<=GEOMETRY;
     end
     1:begin step_x<=quotient;state<=YDIV;end
     2:begin step_y<=quotient;state<=EMIT;end
     default:begin error_code<=1;state<=DONE;end
    endcase
    GEOMETRY:begin left<=(WIDTH-fitted_width)>>1;upper<=(HEIGHT-fitted_height)>>1;state<=XDIV;end
    XDIV:begin numerator<=fitted_width>1?({16'd0,sw}-1'b1)<<16:0;
     denominator<=fitted_width>1?fitted_width-1'b1:1;operation<=1;div_start<=1;state<=WAIT_DIV;end
    YDIV:begin numerator<=fitted_height>1?({16'd0,sh}-1'b1)<<16:0;
     denominator<=fitted_height>1?fitted_height-1'b1:1;operation<=2;div_start<=1;state<=WAIT_DIV;end
    EMIT:if(out_ready)begin
     if(x==WIDTH-1)begin
      x<=0;phase_x<=0;
      if(y==HEIGHT-1)state<=DONE;
      else begin y<=y+1'b1;if(y>=upper&&y<upper+fitted_height-1'b1)phase_y<=phase_y+step_y;end
     end else begin x<=x+1'b1;if(x>=left&&x<left+fitted_width-1'b1)phase_x<=phase_x+step_x;end
     if(address!=WIDTH*HEIGHT-1)address<=address+1'b1;
    end
    DONE:if(done_ready)state<=IDLE;
    default:begin error_code<=1;state<=DONE;end
   endcase
   if(cancel&&state!=IDLE&&state!=DONE)begin error_code<=2;state<=DONE;end
  end
 end
endmodule
