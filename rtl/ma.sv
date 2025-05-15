`timescale 1ns / 1ps

module ma #(
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

  input  [NUM_OF_DDR4-1:0] ma_ddr4_calib_complete_i,
  output                   ma_ddr4_linkup_o,

  input                      ma_start_i,
  input                      ma_select_v_m_i,
  input                      ma_v_load_or_store_i,
  input  [VRF_ADDRWIDTH-1:0] ma_v_m_reg_i,
  input  [ARF_ADDRWIDTH-1:0] ma_a_reg_i,
  input  [ARF_DATAWIDTH-1:0] ma_a_offset_i,
  output                     ma_done_o,

  output                     arf_en_o,
  output                     arf_we_o,
  output [ARF_ADDRWIDTH-1:0] arf_addr_o,
  input  [ARF_DATAWIDTH-1:0] arf_dout_i
);

  // Internal signals for datamover connections
  logic [               0:3]                     m_dm_mrf_start;
  logic [               0:3][DDR4_ADDRWIDTH-1:0] m_dm_mrf_src_axi_addr;
  logic [               0:3][ MRF_ADDRWIDTH-1:0] m_dm_mrf_dst_bram_addr;
  logic [               0:3][              14:0] m_dm_mrf_byte_to_trans;
  logic [               0:3]                     m_dm_mrf_done;

  logic                                          m_dm_vrf_ldr_start;
  logic [DDR4_ADDRWIDTH-1:0]                     m_dm_vrf_ldr_src_axi_addr;
  logic [ VRF_ADDRWIDTH-1:0]                     m_dm_vrf_ldr_dst_bram_addr;
  logic [              14:0]                     m_dm_vrf_ldr_byte_to_trans;
  logic                                          m_dm_vrf_ldr_done;

  logic                                          m_dm_vrf_str_start;
  logic [DDR4_ADDRWIDTH-1:0]                     m_dm_vrf_str_dst_axi_addr;
  logic [ VRF_ADDRWIDTH-1:0]                     m_dm_vrf_str_src_bram_addr;
  logic [              14:0]                     m_dm_vrf_str_byte_to_trans;
  logic                                          m_dm_vrf_str_done;

  ma_controller #(
    .NUM_OF_DDR4   (NUM_OF_DDR4),
    .DDR4_ADDRWIDTH(DDR4_ADDRWIDTH),
    .ARF_ADDRWIDTH (ARF_ADDRWIDTH),
    .ARF_DATAWIDTH (ARF_DATAWIDTH),
    .VRF_ADDRWIDTH (VRF_ADDRWIDTH),
    .VRF_DATAWIDTH (VRF_DATAWIDTH),
    .MRF_ADDRWIDTH (MRF_ADDRWIDTH),
    .MRF_DATAWIDTH (MRF_DATAWIDTH)
  ) ma_controller_inst (
    .clk(clk),
    .rst_n(rst_n),
    .ma_ddr4_calib_complete_i(ma_ddr4_calib_complete_i),
    .ma_ddr4_linkup_o(ma_ddr4_linkup_o),
    .ma_start_i(ma_start_i),
    .ma_select_v_m_i(ma_select_v_m_i),
    .ma_v_load_or_store_i(ma_v_load_or_store_i),
    .ma_v_m_reg_i(ma_v_m_reg_i),
    .ma_a_reg_i(ma_a_reg_i),
    .ma_a_offset_i(ma_a_offset_i),
    .ma_done_o(ma_done_o),
    .arf_en_o(arf_en_o),
    .arf_we_o(arf_we_o),
    .arf_addr_o(arf_addr_o),
    .arf_dout_i(arf_dout_i),
    .m_dm_mrf_start(m_dm_mrf_start),
    .m_dm_mrf_src_axi_addr(m_dm_mrf_src_axi_addr),
    .m_dm_mrf_dst_bram_addr(m_dm_mrf_dst_bram_addr),
    .m_dm_mrf_byte_to_trans(m_dm_mrf_byte_to_trans),
    .m_dm_mrf_done(m_dm_mrf_done),
    .m_dm_vrf_ldr_start(m_dm_vrf_ldr_start),
    .m_dm_vrf_ldr_src_axi_addr(m_dm_vrf_ldr_src_axi_addr),
    .m_dm_vrf_ldr_dst_bram_addr(m_dm_vrf_ldr_dst_bram_addr),
    .m_dm_vrf_ldr_byte_to_trans(m_dm_vrf_ldr_byte_to_trans),
    .m_dm_vrf_ldr_done(m_dm_vrf_ldr_done),
    .m_dm_vrf_str_start(m_dm_vrf_str_start),
    .m_dm_vrf_str_dst_axi_addr(m_dm_vrf_str_dst_axi_addr),
    .m_dm_vrf_str_src_bram_addr(m_dm_vrf_str_src_bram_addr),
    .m_dm_vrf_str_byte_to_trans(m_dm_vrf_str_byte_to_trans),
    .m_dm_vrf_str_done(m_dm_vrf_str_done)
  );

endmodule
