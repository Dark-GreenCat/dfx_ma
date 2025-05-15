`timescale 1ns / 1ps

module arbiter2bram_datamover #(
  parameter AXI_ADDRWIDTH = 36,
  parameter BRAM_ADDRWIDTH = 10,
  parameter DATAWIDTH = 1024
) (
  input logic clk,
  input logic rst_n,

  /* Interface for Controller */
  input                             start_i,
  input        [BRAM_ADDRWIDTH-1:0] src_addr_i,
  input        [ AXI_ADDRWIDTH-1:0] dst_addr_i,
  output logic                      done_o,

  /* Interface for Arbiter */
  output logic                      rd_req,
  input  logic                      rd_gnt,
  output logic [BRAM_ADDRWIDTH-1:0] rd_addr,
  input  logic [     DATAWIDTH-1:0] rd_data,

  /* Interface for BRAM */
  output logic [AXI_ADDRWIDTH-1:0] bram_addr,
  output logic [    DATAWIDTH-1:0] bram_wrdata,
  output logic                     bram_en,
  output logic                     bram_we
);

  typedef enum logic [1:0] {
    IDLE,
    REQ,
    READ,
    READDELAY
  } state_t;

  state_t state, next_state;
  // State transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      IDLE: begin
        next_state = start_i ? REQ : IDLE;
      end
      REQ: begin
        next_state = rd_req ? READ : REQ;
      end
      READ: begin
        next_state = rd_gnt ? READDELAY : READ;
      end
      READDELAY: begin
        next_state = IDLE;
      end
    endcase
  end

  assign bram_wrdata = rd_data;
  // Output and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      done_o    <= 0;

      rd_req    <= 0;
      rd_addr   <= 0;

      bram_addr <= 0;
      bram_en   <= 0;
      bram_we   <= 0;
    end else begin
      if (bram_en && bram_we) done_o <= 1'b1;
      else done_o <= 1'b0;
      case (state)
        IDLE: begin
          rd_req    <= 0;
          rd_addr   <= 0;

          bram_addr <= 0;
          bram_en   <= 0;
          bram_we   <= 0;
        end
        REQ: begin
          rd_req    <= 1'b1;
          rd_addr   <= src_addr_i;
          bram_addr <= dst_addr_i;
        end
        READ: begin

        end
        READDELAY: begin
          bram_en <= 1'b1;
          bram_we <= 1'b1;
        end
      endcase
    end
  end

endmodule
