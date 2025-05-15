`timescale 1ns / 1ps

`include "ma_define.vh"

module axi2bram_datamover #(
  parameter AXI_ADDRWIDTH = 36,
  parameter BRAM_ADDRWIDTH = 10,
  parameter DATAWIDTH = 1024
) (
  input clk,
  input rst_n,

  /* Interface for Controller */
  input                             start_i,
  input        [ AXI_ADDRWIDTH-1:0] src_axi_addr_i,
  input        [BRAM_ADDRWIDTH-1:0] dst_bram_addr_i,
  input        [              14:0] byte_to_trans_i,  // Only support multiple of 128
  output logic                      done_o,

  /* Interface for AXI4 */
  // Read Address Channel (AXI Master outputs)
  output logic [AXI_ADDRWIDTH-1:0] m_axi_araddr,
  output logic [              1:0] m_axi_arburst,
  output logic [              3:0] m_axi_arcache,
  output logic [              7:0] m_axi_arlen,
  output logic                     m_axi_arlock,
  output logic [              2:0] m_axi_arprot,
  output logic [              2:0] m_axi_arsize,
  output logic                     m_axi_arvalid,
  input                            m_axi_arready,
  // Read Data Channel (AXI Master inputs)
  input        [    DATAWIDTH-1:0] m_axi_rdata,
  input                            m_axi_rlast,
  input        [              1:0] m_axi_rresp,
  input                            m_axi_rvalid,
  output logic                     m_axi_rready,

  /* Interface for BRAM */
  output logic [BRAM_ADDRWIDTH-1:0] bram_addr,
  output logic [     DATAWIDTH-1:0] bram_wrdata,
  output logic                      bram_en,
  output logic                      bram_we
);

  localparam IDLE = 2'b00;
  localparam READ_ADDR = 2'b01;
  localparam READ_DATA = 2'b10;

  /******************************************/
  /************* STATE REGISTER *************/
  /******************************************/
  reg [1:0] state, next_state;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end


  /******************************************/
  /************ NEXT STATE LOGIC ************/
  /******************************************/
  always @(state or start_i or m_axi_arready or m_axi_arvalid or m_axi_rvalid or m_axi_rready or
           m_axi_rlast) begin
    case (state)
      IDLE: begin
        if (start_i) begin
          next_state = READ_ADDR;
        end else begin
          next_state = IDLE;
        end
      end
      READ_ADDR: begin
        if (m_axi_arready && m_axi_arvalid) begin
          next_state = READ_DATA;
        end else begin
          next_state = READ_ADDR;
        end
      end
      READ_DATA: begin
        if (m_axi_rvalid && m_axi_rready) begin
          if (m_axi_rlast) begin
            next_state = IDLE;
          end
        end else begin
          next_state = READ_DATA;
        end
      end
      default: next_state = IDLE;
    endcase
  end


  /******************************************/
  /********* INTERNAL & OUTPUT LOGIC ********/
  /******************************************/
  logic done;
  logic [7:0] transfer_count;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      done           <= 0;
      done_o         <= 0;

      m_axi_araddr   <= {AXI_ADDRWIDTH{1'b0}};
      m_axi_arburst  <= `AXI4_AXBURST_DEFAULT;
      m_axi_arcache  <= `AXI4_AXCACHE_DEFAULT;
      m_axi_arlen    <= 8'b0;
      m_axi_arlock   <= `AXI4_AXLOCK_DEFAULT;
      m_axi_arprot   <= `AXI4_AXPROT_DEFAULT;
      m_axi_arsize   <= $clog2(DATAWIDTH / 8);
      m_axi_arvalid  <= 0;

      m_axi_rready   <= 0;

      bram_addr      <= {BRAM_ADDRWIDTH{1'b0}};
      bram_wrdata    <= {DATAWIDTH{1'b0}};
      bram_en        <= 0;
      bram_we        <= 0;

      transfer_count <= 8'b0;
    end else begin
      if (done) done <= 0;
      done_o <= done;

      case (state)
        IDLE: begin
          m_axi_araddr   <= {AXI_ADDRWIDTH{1'b0}};
          m_axi_arburst  <= `AXI4_AXBURST_DEFAULT;
          m_axi_arcache  <= (`AXI4_AXCACHE_DEFAULT | `AXI4_AXCACHE_BIT1_MOD);
          m_axi_arlen    <= 8'b0;
          m_axi_arlock   <= `AXI4_AXLOCK_DEFAULT;
          m_axi_arprot   <= `AXI4_AXPROT_DEFAULT;
          m_axi_arsize   <= $clog2(DATAWIDTH / 8);
          m_axi_arvalid  <= 0;

          m_axi_rready   <= 0;

          bram_addr      <= {BRAM_ADDRWIDTH{1'b0}};
          bram_wrdata    <= {DATAWIDTH{1'b0}};
          bram_en        <= 0;
          bram_we        <= 0;

          transfer_count <= 8'b0;
        end
        READ_ADDR: begin
          m_axi_araddr   <= src_axi_addr_i;
          m_axi_arlen    <= ((byte_to_trans_i >> $clog2(DATAWIDTH / 8)) - 1);
          transfer_count <= 0;
          if (m_axi_arvalid && m_axi_arready) begin
            m_axi_arvalid <= 0;
          end else begin
            m_axi_arvalid <= 1;
          end
        end
        READ_DATA: begin
          m_axi_rready <= 1;

          if (m_axi_rvalid && m_axi_rready) begin
            bram_en        <= 1;
            bram_we        <= 1;
            bram_addr      <= dst_bram_addr_i + transfer_count;
            bram_wrdata    <= m_axi_rdata;
            transfer_count <= transfer_count + 1;

            if (m_axi_rlast) begin
              m_axi_rready <= 0;
              done         <= 1;
            end
          end else begin
            bram_en <= 0;
          end
        end
      endcase
    end
  end
endmodule
