`timescale 1ns/1ps
// 8192 x 28-bit FAT cluster history. Same-clock, independent read/write.
// Read is synchronous (one edge), read_enable=0 holds the last result.
// Contents are not reset: the caller must only read previously written entries.
// Simultaneous read/write of the same address is outside this interface contract.
// Four 2048-word banks, two 16-bit EG4 32K primitives per bank.
// PORTABLE=1 is a reference implementation, not a vendor primitive simulation.
module station_cluster_history32k #(
 parameter integer PORTABLE=0
)(
 input wire clk,
 input wire read_enable,input wire [12:0] read_address,
 output wire [27:0] read_data,
 input wire write_enable,input wire [12:0] write_address,
 input wire [27:0] write_data
);
 generate if(PORTABLE) begin: reference_ram
  reg [27:0] words[0:8191];
  reg [27:0] result;
  always @(posedge clk) begin
   if(write_enable) words[write_address]<=write_data;
   if(read_enable) result<=words[read_address];
  end
  assign read_data=result;
 end else begin: eg4_ram
  reg [1:0] selected_bank;
  wire [27:0] bank_data[0:3];
  always @(posedge clk) if(read_enable) selected_bank<=read_address[12:11];
  genvar bank;
  for(bank=0;bank<4;bank=bank+1) begin: banks
   wire [15:0] low_data,high_data;
   wire read_select=read_enable&&(read_address[12:11]==bank);
   wire write_select=write_enable&&(write_address[12:11]==bank);
   EG_PHY_BRAM32K #(
    .MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
    .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.SRMODE("SYNC")
   ) low_ram (
    .doa(low_data),.dia(16'b0),.addra(read_address[10:0]),
    .bytea(1'b0),.bytewea(1'b0),.csa(read_select),.wea(1'b0),
    .clka(clk),.rsta(1'b0),.ocea(1'b1),
    .dob(),.dib(write_data[15:0]),.addrb(write_address[10:0]),
    .byteb(1'b0),.byteweb(1'b0),.csb(write_select),.web(1'b1),
    .clkb(clk),.rstb(1'b0),.oceb(1'b1)
   );
   EG_PHY_BRAM32K #(
    .MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
    .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.SRMODE("SYNC")
   ) high_ram (
    .doa(high_data),.dia(16'b0),.addra(read_address[10:0]),
    .bytea(1'b0),.bytewea(1'b0),.csa(read_select),.wea(1'b0),
    .clka(clk),.rsta(1'b0),.ocea(1'b1),
    .dob(),.dib({4'b0,write_data[27:16]}),.addrb(write_address[10:0]),
    .byteb(1'b0),.byteweb(1'b0),.csb(write_select),.web(1'b1),
    .clkb(clk),.rstb(1'b0),.oceb(1'b1)
   );
   assign bank_data[bank]={high_data[11:0],low_data};
  end
  assign read_data=bank_data[selected_bank];
 end endgenerate
endmodule
