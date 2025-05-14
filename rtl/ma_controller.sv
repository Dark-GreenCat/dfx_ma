`timescale 1ns / 1ps

`include "ma_define.sv"

module ma_controller #(
  parameter NUM_OF_DDR4 = 4,
  parameter DDR4_ADDRWIDTH = 36,
  parameter ARF_ADDRWIDTH = 5,
  parameter ARF_DATAWIDTH = DDR4_ADDRWIDTH,
  parameter VRF_ADDRWIDTH = 10,
  parameter VRF_DATAWIDTH = 1024,
  parameter MRF_ADDRWIDTH = 6,
  parameter MRF_DATAWIDTH = 1024
) (
  input clk,
  input rst_n,

  input      [NUM_OF_DDR4-1:0] ma_ddr4_calib_complete_i,
  output reg                   ma_ddr4_linkup_o,

  input                          ma_start_i,
  input                          ma_select_v_m_i,
  input                          ma_v_load_or_store_i,
  input      [VRF_ADDRWIDTH-1:0] ma_v_m_reg_i,
  input      [ARF_ADDRWIDTH-1:0] ma_a_reg_i,
  input      [ARF_DATAWIDTH-1:0] ma_a_offset_i,
  output reg                     ma_done_o,

  output reg                     arf_en_o,
  output reg                     arf_we_o,
  output reg [ARF_ADDRWIDTH-1:0] arf_addr_o,
  input      [ARF_DATAWIDTH-1:0] arf_dout_i,

  datamover_if.master m_dm_mrf3,
  datamover_if.master m_dm_mrf2,
  datamover_if.master m_dm_mrf1,
  datamover_if.master m_dm_mrf0,
  datamover_if.master m_dm_vrf_ldr,
  datamover_if.master m_dm_vrf_str
);

    // Parameterize the interfaces
    // MRF interfaces (AXI2BRAM)
  defparam m_dm_mrf3.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_mrf3.BRAM_ADDR_WIDTH = MRF_ADDRWIDTH;
  defparam m_dm_mrf3.BYTE_TRANS_WIDTH = 15;

  defparam m_dm_mrf2.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_mrf2.BRAM_ADDR_WIDTH = MRF_ADDRWIDTH;
  defparam m_dm_mrf2.BYTE_TRANS_WIDTH = 15;

  defparam m_dm_mrf1.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_mrf1.BRAM_ADDR_WIDTH = MRF_ADDRWIDTH;
  defparam m_dm_mrf1.BYTE_TRANS_WIDTH = 15;

  defparam m_dm_mrf0.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_mrf0.BRAM_ADDR_WIDTH = MRF_ADDRWIDTH;
  defparam m_dm_mrf0.BYTE_TRANS_WIDTH = 15;

  // VRF Load interface (AXI2BRAM)
  defparam m_dm_vrf_ldr.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_vrf_ldr.BRAM_ADDR_WIDTH = VRF_ADDRWIDTH;
  defparam m_dm_vrf_ldr.BYTE_TRANS_WIDTH = 15;

  // VRF Store interface (BRAM2AXI)
  defparam m_dm_vrf_str.AXI_ADDR_WIDTH = DDR4_ADDRWIDTH;
  defparam m_dm_vrf_str.BRAM_ADDR_WIDTH = VRF_ADDRWIDTH;
  defparam m_dm_vrf_str.BYTE_TRANS_WIDTH = 15;

  typedef enum logic [2:0] {
    WAIT_CALIB,
    IDLE,
    READ_ARF,
    WAIT_ARF,
    WAIT_ARF2,
    CALC_ADDR,
    START_TRANSFER,
    WAIT_DONE
  } state_t;

  state_t state, next_state;

  reg [DDR4_ADDRWIDTH-1:0] base_addr;
  reg [DDR4_ADDRWIDTH-1:0] effective_addr;

  // State transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= WAIT_CALIB;
    else state <= next_state;
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      WAIT_CALIB: if (&ma_ddr4_calib_complete_i) next_state = IDLE;
      IDLE: if (ma_start_i) next_state = READ_ARF;
      READ_ARF: next_state = WAIT_ARF;
      WAIT_ARF: next_state = WAIT_ARF2;
      WAIT_ARF2: next_state = CALC_ADDR;
      CALC_ADDR: next_state = START_TRANSFER;
      START_TRANSFER: next_state = WAIT_DONE;
      WAIT_DONE:
      if (m_dm_mrf3.done | m_dm_mrf2.done | m_dm_mrf1.done | m_dm_mrf0.done) next_state = IDLE;
    endcase
  end

  // Output and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ma_ddr4_linkup_o           <= 0;
      arf_en_o                   <= 0;
      arf_we_o                   <= 0;
      arf_addr_o                 <= 0;
      ma_done_o                  <= 0;
      effective_addr             <= 0;
      base_addr                  <= 0;
      m_dm_mrf3.start            <= 0;
      m_dm_mrf2.start            <= 0;
      m_dm_mrf1.start            <= 0;
      m_dm_mrf0.start            <= 0;
      m_dm_vrf_ldr.start         <= 0;
      m_dm_vrf_str.start         <= 0;
      m_dm_mrf3.src_axi_addr     <= 0;
      m_dm_mrf2.src_axi_addr     <= 0;
      m_dm_mrf1.src_axi_addr     <= 0;
      m_dm_mrf0.src_axi_addr     <= 0;
      m_dm_vrf_ldr.src_axi_addr  <= 0;
      m_dm_vrf_str.dst_axi_addr  <= 0;
      m_dm_mrf3.dst_bram_addr    <= 0;
      m_dm_mrf2.dst_bram_addr    <= 0;
      m_dm_mrf1.dst_bram_addr    <= 0;
      m_dm_mrf0.dst_bram_addr    <= 0;
      m_dm_vrf_ldr.dst_bram_addr <= 0;
      m_dm_vrf_str.src_bram_addr <= 0;
      m_dm_mrf3.byte_to_trans    <= 0;
      m_dm_mrf2.byte_to_trans    <= 0;
      m_dm_mrf1.byte_to_trans    <= 0;
      m_dm_mrf0.byte_to_trans    <= 0;
      m_dm_vrf_ldr.byte_to_trans <= 0;
      m_dm_vrf_str.byte_to_trans <= 0;
    end else begin
      case (state)
        WAIT_CALIB: begin
          ma_ddr4_linkup_o <= &ma_ddr4_calib_complete_i;
          ma_done_o        <= 0;
        end

        IDLE: begin
          arf_en_o           <= 0;
          ma_done_o          <= 0;
          m_dm_mrf3.start    <= 0;
          m_dm_mrf2.start    <= 0;
          m_dm_mrf1.start    <= 0;
          m_dm_mrf0.start    <= 0;
          m_dm_vrf_ldr.start <= 0;
          m_dm_vrf_str.start <= 0;
        end

        READ_ARF: begin
          arf_en_o   <= 1;
          arf_we_o   <= 0;
          arf_addr_o <= ma_a_reg_i;
        end

        WAIT_ARF: begin
          arf_en_o  <= 1;
          base_addr <= arf_dout_i;
        end

        WAIT_ARF2: begin
          arf_en_o  <= 0;
          base_addr <= arf_dout_i;
        end

        CALC_ADDR: begin
          arf_en_o       <= 0;
          base_addr      <= arf_dout_i;
          effective_addr <= arf_dout_i + ma_a_offset_i;
        end

        START_TRANSFER: begin
          if (ma_select_v_m_i) begin
            m_dm_mrf3.start         <= 1;
            m_dm_mrf2.start         <= 1;
            m_dm_mrf1.start         <= 1;
            m_dm_mrf0.start         <= 1;
            m_dm_mrf3.src_axi_addr  <= effective_addr;
            m_dm_mrf2.src_axi_addr  <= effective_addr + 15'd2048;
            m_dm_mrf1.src_axi_addr  <= effective_addr + 15'd4096;
            m_dm_mrf0.src_axi_addr  <= effective_addr + 15'd6144;
            m_dm_mrf3.dst_bram_addr <= ma_v_m_reg_i[MRF_ADDRWIDTH-1:0];
            m_dm_mrf2.dst_bram_addr <= ma_v_m_reg_i[MRF_ADDRWIDTH-1:0];
            m_dm_mrf1.dst_bram_addr <= ma_v_m_reg_i[MRF_ADDRWIDTH-1:0];
            m_dm_mrf0.dst_bram_addr <= ma_v_m_reg_i[MRF_ADDRWIDTH-1:0];
            m_dm_mrf3.byte_to_trans <= 15'd2048;
            m_dm_mrf2.byte_to_trans <= 15'd2048;
            m_dm_mrf1.byte_to_trans <= 15'd2048;
            m_dm_mrf0.byte_to_trans <= 15'd2048;
          end else begin
            if (ma_v_load_or_store_i == 0) begin
              m_dm_vrf_ldr.start         <= 1;
              m_dm_vrf_ldr.src_axi_addr  <= effective_addr;
              m_dm_vrf_ldr.dst_bram_addr <= ma_v_m_reg_i[VRF_ADDRWIDTH-1:0];
              m_dm_vrf_ldr.byte_to_trans <= 15'd128;
            end else begin
              m_dm_vrf_str.start         <= 1;
              m_dm_vrf_str.dst_axi_addr  <= effective_addr;
              m_dm_vrf_str.src_bram_addr <= ma_v_m_reg_i[VRF_ADDRWIDTH-1:0];
              m_dm_vrf_str.byte_to_trans <= 15'd128;
            end
          end
        end

        WAIT_DONE: begin
          m_dm_mrf3.start    <= 0;
          m_dm_mrf2.start    <= 0;
          m_dm_mrf1.start    <= 0;
          m_dm_mrf0.start    <= 0;
          m_dm_vrf_ldr.start <= 0;
          m_dm_vrf_str.start <= 0;
          if (ma_select_v_m_i) begin
            ma_done_o <= m_dm_mrf3.done & m_dm_mrf2.done & m_dm_mrf1.done & m_dm_mrf0.done;
          end else begin
            if (ma_v_load_or_store_i == 0) ma_done_o <= m_dm_vrf_ldr.done;
            else ma_done_o <= m_dm_vrf_str.done;
          end
        end
      endcase
    end
  end

endmodule
