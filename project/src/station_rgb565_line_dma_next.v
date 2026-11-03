// Parent SHA256 1e183ae2b9f089003a2d640bca8c9a928e54ffef873bb2ca7c3a93d78139f386
`timescale 1ns/1ps
// Same-business-clock line DMA; NOT the asynchronous pixel line cache.
// Caller reserves an entire cache bank before row_valid/row_ready and retains
// it until line_done (or discards it on fault). Word output cannot be stalled.
// Row request carries displayed global PTS, rejecting stale frame requests.
// Swaps allowed only while idle; block requests on the actual publish clock.
module station_rgb565_line_dma(
 input wire clk,rst_n,enabled,publish,
 input wire display_valid,display_slot,input wire [63:0] display_pts,
 input wire [15:0] display_width,display_height,
 input wire row_valid,output wire row_ready,input wire [8:0] row,
 input wire [63:0] row_pts,
 output wire rd_valid,input wire rd_ready,output wire [20:0] rd_address,
 input wire rd_data_valid,input wire [31:0] rd_data,input wire rd_last,
 output wire word_valid,output wire [7:0] word_index,output wire [31:0] word_data,
 output reg line_done,line_rejected,output reg [8:0] line_row,
 output reg [63:0] line_pts,output wire idle,output reg fault
);
 localparam IDLE=0,OFFER=1,FILL=2;
 reg [1:0] state;reg slot;reg [7:0] offset,words_per_line;reg [2:0] beat;
 // Precompute during OFFER/FILL. Consumed only on the eighth returned beat,
 // at least nine clocks after the previous offset update; never on stale q.
 reg [8:0] offset_after_burst;
 wire correct_shape=(display_width==320&&display_height==180)||
                    (display_width==480&&display_height==270);
 assign idle=rst_n&&state==IDLE;
 assign row_ready=idle&&enabled&&!publish&&!fault;
 assign rd_valid=rst_n&&state==OFFER&&!fault;
 assign rd_address=(slot?21'd73728:21'd0)+{4'b0,line_row,8'b0}+{13'b0,offset};
 assign word_valid=rst_n&&state==FILL&&rd_data_valid&&!fault&&(rd_last==(beat==7));
 assign word_index=offset+{5'b0,beat};assign word_data=rd_data;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;slot<=0;offset<=0;words_per_line<=0;beat<=0;offset_after_burst<=9'd8;
   line_done<=0;line_rejected<=0;line_row<=0;line_pts<=0;fault<=0;
  end else begin
   line_done<=0;line_rejected<=0;
   offset_after_burst<={1'b0,offset}+9'd8;
   if(rd_data_valid&&state!=FILL)fault<=1;
   if(publish&&state!=IDLE)fault<=1;
   case(state)
    IDLE:if(row_valid&&row_ready)begin
     if(!display_valid||row_pts!=display_pts||row>=display_height)line_rejected<=1;
     else if(!correct_shape)fault<=1;
     else begin
      slot<=display_slot;line_row<=row;line_pts<=display_pts;
      words_per_line<=display_width==320?8'd160:8'd240;
      offset<=0;offset_after_burst<=9'd8;beat<=0;state<=OFFER;
     end
    end
    OFFER:if(rd_valid&&rd_ready)begin state<=FILL;beat<=0;end
    FILL:if(rd_data_valid)begin
     if(rd_last!=(beat==7))fault<=1;
     if(beat==7)begin
      if(offset_after_burst=={1'b0,words_per_line})begin state<=IDLE;line_done<=!fault&&rd_last&&!publish;end
      else begin offset<=offset_after_burst[7:0];state<=OFFER;end
     end else beat<=beat+1'b1;
    end
    default:begin state<=IDLE;fault<=1;end
   endcase
  end
 end
endmodule
