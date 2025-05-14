`timescale 1ns / 1ps

`include "ma_define.sv"

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

  // Internal instantiation of datamover interfaces
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (MRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_mrf3 ();
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (MRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_mrf2 ();
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (MRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_mrf1 ();
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (MRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_mrf0 ();
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (VRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_vrf_ldr ();
  datamover_if #(
    .AXI_ADDR_WIDTH  (DDR4_ADDRWIDTH),
    .BRAM_ADDR_WIDTH (VRF_ADDRWIDTH),
    .BYTE_TRANS_WIDTH(15)
  ) m_dm_vrf_str ();

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
    .m_dm_mrf3(m_dm_mrf3.master),
    .m_dm_mrf2(m_dm_mrf2.master),
    .m_dm_mrf1(m_dm_mrf1.master),
    .m_dm_mrf0(m_dm_mrf0.master),
    .m_dm_vrf_ldr(m_dm_vrf_ldr.master),
    .m_dm_vrf_str(m_dm_vrf_str.master)
  );

endmodule
