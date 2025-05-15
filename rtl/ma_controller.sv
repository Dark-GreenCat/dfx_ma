`timescale 1ns / 1ps

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

  // MRF signals (array for four channels: mrf0, mrf1, mrf2, mrf3)
  output logic [0:3]                     m_dm_mrf_start,
  output logic [0:3][DDR4_ADDRWIDTH-1:0] m_dm_mrf_src_axi_addr,
  output logic [0:3][ MRF_ADDRWIDTH-1:0] m_dm_mrf_dst_bram_addr,
  output logic [0:3][              14:0] m_dm_mrf_byte_to_trans,
  input        [0:3]                     m_dm_mrf_done,

  // VRF load signals
  output logic                      m_dm_vrf_ldr_start,
  output logic [DDR4_ADDRWIDTH-1:0] m_dm_vrf_ldr_src_axi_addr,
  output logic [ VRF_ADDRWIDTH-1:0] m_dm_vrf_ldr_dst_bram_addr,
  output logic [              14:0] m_dm_vrf_ldr_byte_to_trans,
  input                             m_dm_vrf_ldr_done,

  // VRF store signals
  output logic                      m_dm_vrf_str_start,
  output logic [DDR4_ADDRWIDTH-1:0] m_dm_vrf_str_dst_axi_addr,
  output logic [ VRF_ADDRWIDTH-1:0] m_dm_vrf_str_src_bram_addr,
  output logic [              14:0] m_dm_vrf_str_byte_to_trans,
  input                             m_dm_vrf_str_done
);

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
      WAIT_CALIB:     if (&ma_ddr4_calib_complete_i) next_state = IDLE;
      IDLE:           if (ma_start_i) next_state = READ_ARF;
      READ_ARF:       next_state = WAIT_ARF;
      WAIT_ARF:       next_state = WAIT_ARF2;
      WAIT_ARF2:      next_state = CALC_ADDR;
      CALC_ADDR:      next_state = START_TRANSFER;
      START_TRANSFER: next_state = WAIT_DONE;
      WAIT_DONE:
      if (ma_select_v_m_i) begin
        if (&m_dm_mrf_done) next_state = IDLE;
      end else begin
        if (m_dm_vrf_ldr_done | m_dm_vrf_str_done) next_state = IDLE;
      end
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
      m_dm_mrf_start             <= 0;
      m_dm_vrf_ldr_start         <= 0;
      m_dm_vrf_str_start         <= 0;
      m_dm_mrf_src_axi_addr      <= 0;
      m_dm_vrf_ldr_src_axi_addr  <= 0;
      m_dm_vrf_str_dst_axi_addr  <= 0;
      m_dm_mrf_dst_bram_addr     <= 0;
      m_dm_vrf_ldr_dst_bram_addr <= 0;
      m_dm_vrf_str_src_bram_addr <= 0;
      m_dm_mrf_byte_to_trans     <= 0;
      m_dm_vrf_ldr_byte_to_trans <= 0;
      m_dm_vrf_str_byte_to_trans <= 0;
    end else begin
      case (state)
        WAIT_CALIB: begin
          ma_ddr4_linkup_o <= &ma_ddr4_calib_complete_i;
          ma_done_o        <= 0;
        end

        IDLE: begin
          arf_en_o           <= 0;
          ma_done_o          <= 0;
          m_dm_mrf_start     <= 0;
          m_dm_vrf_ldr_start <= 0;
          m_dm_vrf_str_start <= 0;
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
            m_dm_mrf_start[0] <= 1;  // mrf0
            m_dm_mrf_start[1] <= 1;  // mrf1
            m_dm_mrf_start[2] <= 1;  // mrf2
            m_dm_mrf_start[3] <= 1;  // mrf3
            m_dm_mrf_src_axi_addr[0] <= effective_addr + 15'd6144;  // mrf0
            m_dm_mrf_src_axi_addr[1] <= effective_addr + 15'd4096;  // mrf1
            m_dm_mrf_src_axi_addr[2] <= effective_addr + 15'd2048;  // mrf2
            m_dm_mrf_src_axi_addr[3] <= effective_addr;  // mrf3
            m_dm_mrf_dst_bram_addr[0] <= {ma_v_m_reg_i[1:0], 4'b0000};  // Translated 2-bit to 6-bit
            m_dm_mrf_dst_bram_addr[1] <= {ma_v_m_reg_i[1:0], 4'b0000};  // Same for all channels
            m_dm_mrf_dst_bram_addr[2] <= {ma_v_m_reg_i[1:0], 4'b0000};
            m_dm_mrf_dst_bram_addr[3] <= {ma_v_m_reg_i[1:0], 4'b0000};
            m_dm_mrf_byte_to_trans[0] <= 15'd2048;
            m_dm_mrf_byte_to_trans[1] <= 15'd2048;
            m_dm_mrf_byte_to_trans[2] <= 15'd2048;
            m_dm_mrf_byte_to_trans[3] <= 15'd2048;
          end else begin
            if (ma_v_load_or_store_i == 0) begin
              m_dm_vrf_ldr_start         <= 1;
              m_dm_vrf_ldr_src_axi_addr  <= effective_addr;
              m_dm_vrf_ldr_dst_bram_addr <= ma_v_m_reg_i[VRF_ADDRWIDTH-1:0];
              m_dm_vrf_ldr_byte_to_trans <= 15'd128;
            end else begin
              m_dm_vrf_str_start         <= 1;
              m_dm_vrf_str_dst_axi_addr  <= effective_addr;
              m_dm_vrf_str_src_bram_addr <= ma_v_m_reg_i[VRF_ADDRWIDTH-1:0];
              m_dm_vrf_str_byte_to_trans <= 15'd128;
            end
          end
        end

        WAIT_DONE: begin
          m_dm_mrf_start     <= 0;
          m_dm_vrf_ldr_start <= 0;
          m_dm_vrf_str_start <= 0;
          if (ma_select_v_m_i) begin
            ma_done_o <= &m_dm_mrf_done;
          end else begin
            if (ma_v_load_or_store_i == 0) ma_done_o <= m_dm_vrf_ldr_done;
            else ma_done_o <= m_dm_vrf_str_done;
          end
        end
      endcase
    end
  end

endmodule
