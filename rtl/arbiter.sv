`timescale 1ns / 1ps

module arbiter #(
  parameter LATENCY = 10
) (
  input clk,
  input rst_n,

  /* Interface for User Logic */
  input                 wr_req,
  output logic          wr_gnt,
  input        [   9:0] wr_addr,
  input        [1023:0] wr_data,

  /* Interface for VRF */
  output logic [   9:0] addra,
  input        [1023:0] douta,
  output logic [1023:0] dina,
  output logic          ena,
  output logic          wea
);

  logic [$clog2(LATENCY):0] cnt;

  // Sequential logic for counter
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      cnt <= 0;
    end else if (!wr_req) begin
      cnt <= 0;
    end else if (cnt < LATENCY) begin
      cnt <= cnt + 1;
    end
  end

  // Combinational logic for outputs
  always @(*) begin
    wr_gnt = (cnt == LATENCY) & wr_req;
    addra  = (cnt == LATENCY) ? wr_addr : 10'b0;
    dina   = (cnt == LATENCY) ? wr_data : 1024'b0;
    ena    = (cnt == LATENCY) & wr_req;
    wea    = (cnt == LATENCY) & wr_req;
  end

endmodule
