`timescale 1ns/1ps
// 16 x24-bit dual-port cache. Same-clock read takes one edge; disabled read
// holds its result. No reset/initialization: caller must fill a line before
// marking its tag valid. Same-address simultaneous read/write is unsupported.
// Two known EG4 16-bit port configurations trade spare RAM32K for LUTs.
module station_photo_cache32k #(
 parameter integer PORTABLE=0
)(
 input wire clk,
 input wire read_enable,input wire [3:0] read_address,output wire [23:0] read_data,
 input wire write_enable,input wire [3:0] write_address,input wire [23:0] write_data
);
 generate if(PORTABLE)begin:reference_ram
  reg [23:0] words[0:15];reg [23:0] result;
  always @(posedge clk)begin
   if(write_enable)words[write_address]<=write_data;
   if(read_enable)result<=words[read_address];
  end
  assign read_data=result;
 end else begin:eg4_ram
  wire [15:0] low_data,high_data;
  EG_PHY_BRAM32K #(
   .MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
   .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
   .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.SRMODE("SYNC")
  ) low_ram(
   .doa(low_data),.dia(16'b0),.addra({7'b0,read_address}),
   .bytea(1'b0),.bytewea(1'b0),.csa(read_enable),.wea(1'b0),
   .clka(clk),.rsta(1'b0),.ocea(1'b1),
   .dob(),.dib(write_data[15:0]),.addrb({7'b0,write_address}),
   .byteb(1'b0),.byteweb(1'b0),.csb(write_enable),.web(1'b1),
   .clkb(clk),.rstb(1'b0),.oceb(1'b1)
  );
  EG_PHY_BRAM32K #(
   .MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
   .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
   .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.SRMODE("SYNC")
  ) high_ram(
   .doa(high_data),.dia(16'b0),.addra({7'b0,read_address}),
   .bytea(1'b0),.bytewea(1'b0),.csa(read_enable),.wea(1'b0),
   .clka(clk),.rsta(1'b0),.ocea(1'b1),
   .dob(),.dib({8'b0,write_data[23:16]}),.addrb({7'b0,write_address}),
   .byteb(1'b0),.byteweb(1'b0),.csb(write_enable),.web(1'b1),
   .clkb(clk),.rstb(1'b0),.oceb(1'b1)
  );
  assign read_data={high_data[7:0],low_data};
 end endgenerate
endmodule
