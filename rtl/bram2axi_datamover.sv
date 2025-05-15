`timescale 1ns / 1ps

module bram2axi_datamover #(
  parameter AXI_ADDRWIDTH = 36,
  parameter DATAWIDTH = 1024
) (
  input clk,
  input rst_n,

  /* Interface for Controller */
  output logic done_o,

  /* Interface for BRAM */
  input logic [AXI_ADDRWIDTH-1:0] bram_addr,
  input logic [    DATAWIDTH-1:0] bram_wrdata,
  input logic                     bram_en,
  input logic                     bram_we,

  /* Interface for AXI4 Write Channels */
  // Write Address Channel (AXI Master outputs)
  output logic [AXI_ADDRWIDTH-1:0] m_axi_awaddr,
  output logic [              1:0] m_axi_awburst,
  output logic [              3:0] m_axi_awcache,
  output logic [              7:0] m_axi_awlen,
  output logic                     m_axi_awlock,
  output logic [              2:0] m_axi_awprot,
  output logic [              2:0] m_axi_awsize,
  output logic                     m_axi_awvalid,
  input                            m_axi_awready,

  // Write Data Channel (AXI Master outputs)
  output logic [  DATAWIDTH-1:0] m_axi_wdata,
  output logic                   m_axi_wlast,
  output logic [DATAWIDTH/8-1:0] m_axi_wstrb,
  output logic                   m_axi_wvalid,
  input                          m_axi_wready,

  // Write Response Channel (AXI Master inputs)
  input        [1:0] m_axi_bresp,
  input              m_axi_bvalid,
  output logic       m_axi_bready
);

  typedef enum logic [1:0] {
    IDLE,
    WRITE_ADDR,
    WRITE_DATA,
    WRITE_RESP
  } state_t;

  state_t state, next_state;
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      IDLE: begin
        next_state = (bram_en && bram_we) ? WRITE_ADDR : IDLE;
      end
      WRITE_ADDR: begin
        next_state = (m_axi_awvalid && m_axi_awready) ? WRITE_DATA : WRITE_ADDR;
      end
      WRITE_DATA: begin
        if (m_axi_wvalid && m_axi_wready) begin
          next_state = WRITE_RESP;
        end else begin
          next_state = WRITE_DATA;
        end
      end
      WRITE_RESP: begin
        if (m_axi_bvalid && m_axi_bready) begin
          next_state = IDLE;
        end else begin
          next_state = WRITE_RESP;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      done_o        <= 0;

      m_axi_awaddr  <= 0;
      m_axi_awburst <= 0;
      m_axi_awcache <= 0;
      m_axi_awlen   <= 0;
      m_axi_awlock  <= 0;
      m_axi_awprot  <= 0;
      m_axi_awsize  <= 0;
      m_axi_awvalid <= 0;

      m_axi_wdata   <= 0;
      m_axi_wlast   <= 0;
      m_axi_wstrb   <= 0;
      m_axi_wvalid  <= 0;

      m_axi_bready  <= 0;
    end else begin
      case (state)
        IDLE: begin
          done_o        <= 0;

          m_axi_awaddr  <= bram_addr;
          m_axi_awburst <= 0;
          m_axi_awcache <= 0;
          m_axi_awlen   <= 0;
          m_axi_awlock  <= 0;
          m_axi_awprot  <= 0;
          m_axi_awsize  <= 0;
          m_axi_awvalid <= 0;

          m_axi_wdata   <= 0;
          m_axi_wlast   <= 0;
          m_axi_wstrb   <= 0;
          m_axi_wvalid  <= 0;

          m_axi_bready  <= 0;
        end
        WRITE_ADDR: begin
          // m_axi_awaddr  <= bram_addr;
          m_axi_awburst <= 2'b01;  // INCR
          m_axi_awcache <= 4'b0000;  // Normal Non-cacheable
          m_axi_awlen   <= 'd0;  // Burst length of 1
          m_axi_awlock  <= 1'b0;  // Normal access
          m_axi_awprot  <= 3'b000;  // Unprivileged access
          m_axi_awsize  <= $clog2(DATAWIDTH / 8);  // Data size
          m_axi_awvalid <= 1'b1;  // Assert valid

          if (m_axi_awready && m_axi_awvalid) begin
            m_axi_awvalid <= 1'b0;  // Clear valid after ready
          end
        end
        WRITE_DATA: begin
          m_axi_wdata  <= bram_wrdata;
          m_axi_wlast  <= 1'b1;  // Last data in burst
          m_axi_wstrb  <= {(DATAWIDTH / 8) {1'b1}};  // All bytes valid
          m_axi_bready <= 1'b1;
        end
        WRITE_RESP: begin
          if (m_axi_bready && m_axi_bvalid) begin
            done_o       <= 1;
            m_axi_bready <= 0;
          end
        end
      endcase
    end
  end
endmodule
