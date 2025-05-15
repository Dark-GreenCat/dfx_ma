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
  input  [ARF_DATAWIDTH-1:0] arf_dout_i,

  // AXI4 ports for mrf0 to mrf3
  output [0:3][DDR4_ADDRWIDTH-1:0] m_dm_mrf_m_axi_araddr,
  output [0:3][               1:0] m_dm_mrf_m_axi_arburst,
  output [0:3][               3:0] m_dm_mrf_m_axi_arcache,
  output [0:3][               7:0] m_dm_mrf_m_axi_arlen,
  output [0:3]                     m_dm_mrf_m_axi_arlock,
  output [0:3][               2:0] m_dm_mrf_m_axi_arprot,
  output [0:3][               2:0] m_dm_mrf_m_axi_arsize,
  output [0:3]                     m_dm_mrf_m_axi_arvalid,
  input  [0:3]                     m_dm_mrf_m_axi_arready,
  input  [0:3][ MRF_DATAWIDTH-1:0] m_dm_mrf_m_axi_rdata,
  input  [0:3]                     m_dm_mrf_m_axi_rlast,
  input  [0:3][               1:0] m_dm_mrf_m_axi_rresp,
  input  [0:3]                     m_dm_mrf_m_axi_rvalid,
  output [0:3]                     m_dm_mrf_m_axi_rready,

  // BRAM ports for mrf0 to mrf3
  output [0:3][MRF_ADDRWIDTH-1:0] m_dm_mrf_bram_addr,
  output [0:3][MRF_DATAWIDTH-1:0] m_dm_mrf_bram_wrdata,
  output [0:3]                    m_dm_mrf_bram_en,
  output [0:3]                    m_dm_mrf_bram_we,

  // AXI4 ports for vrf_ldr
  output [DDR4_ADDRWIDTH-1:0] m_dm_vrf_ldr_m_axi_araddr,
  output [               1:0] m_dm_vrf_ldr_m_axi_arburst,
  output [               3:0] m_dm_vrf_ldr_m_axi_arcache,
  output [               7:0] m_dm_vrf_ldr_m_axi_arlen,
  output                      m_dm_vrf_ldr_m_axi_arlock,
  output [               2:0] m_dm_vrf_ldr_m_axi_arprot,
  output [               2:0] m_dm_vrf_ldr_m_axi_arsize,
  output                      m_dm_vrf_ldr_m_axi_arvalid,
  input                       m_dm_vrf_ldr_m_axi_arready,
  input  [ VRF_DATAWIDTH-1:0] m_dm_vrf_ldr_m_axi_rdata,
  input                       m_dm_vrf_ldr_m_axi_rlast,
  input  [               1:0] m_dm_vrf_ldr_m_axi_rresp,
  input                       m_dm_vrf_ldr_m_axi_rvalid,
  output                      m_dm_vrf_ldr_m_axi_rready,

  // Arbiter ports for vrf_ldr
  output                     m_dm_vrf_ldr_done_o,
  output                     m_dm_vrf_ldr_full_o,
  output                     m_dm_vrf_ldr_wr_req,
  input                      m_dm_vrf_ldr_wr_gnt,
  output [VRF_ADDRWIDTH-1:0] m_dm_vrf_ldr_wr_addr,
  output [VRF_DATAWIDTH-1:0] m_dm_vrf_ldr_wr_data
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

  // Internal BRAM signals for vrf_ldr (between axi2bram and bram2arbiter)
  logic [ VRF_ADDRWIDTH-1:0]                     vrf_ldr_bram_addr;
  logic [ VRF_DATAWIDTH-1:0]                     vrf_ldr_bram_wrdata;
  logic                                          vrf_ldr_bram_en;
  logic                                          vrf_ldr_bram_we;

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
    .m_dm_vrf_ldr_done(m_dm_vrf_ldr_done_o),
    .m_dm_vrf_str_start(m_dm_vrf_str_start),
    .m_dm_vrf_str_dst_axi_addr(m_dm_vrf_str_dst_axi_addr),
    .m_dm_vrf_str_src_bram_addr(m_dm_vrf_str_src_bram_addr),
    .m_dm_vrf_str_byte_to_trans(m_dm_vrf_str_byte_to_trans),
    .m_dm_vrf_str_done(m_dm_vrf_str_done)
  );

  // Datamover for mrf0
  axi2bram_datamover #(
    .AXI_ADDRWIDTH (DDR4_ADDRWIDTH),
    .BRAM_ADDRWIDTH(MRF_ADDRWIDTH),
    .DATAWIDTH     (MRF_DATAWIDTH)
  ) axi2bram_datamover_mrf0_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(m_dm_mrf_start[0]),
    .src_axi_addr_i(m_dm_mrf_src_axi_addr[0]),
    .dst_bram_addr_i(m_dm_mrf_dst_bram_addr[0]),
    .byte_to_trans_i(m_dm_mrf_byte_to_trans[0]),
    .done_o(m_dm_mrf_done[0]),
    .m_axi_araddr(m_dm_mrf_m_axi_araddr[0]),
    .m_axi_arburst(m_dm_mrf_m_axi_arburst[0]),
    .m_axi_arcache(m_dm_mrf_m_axi_arcache[0]),
    .m_axi_arlen(m_dm_mrf_m_axi_arlen[0]),
    .m_axi_arlock(m_dm_mrf_m_axi_arlock[0]),
    .m_axi_arprot(m_dm_mrf_m_axi_arprot[0]),
    .m_axi_arsize(m_dm_mrf_m_axi_arsize[0]),
    .m_axi_arvalid(m_dm_mrf_m_axi_arvalid[0]),
    .m_axi_arready(m_dm_mrf_m_axi_arready[0]),
    .m_axi_rdata(m_dm_mrf_m_axi_rdata[0]),
    .m_axi_rlast(m_dm_mrf_m_axi_rlast[0]),
    .m_axi_rresp(m_dm_mrf_m_axi_rresp[0]),
    .m_axi_rvalid(m_dm_mrf_m_axi_rvalid[0]),
    .m_axi_rready(m_dm_mrf_m_axi_rready[0]),
    .bram_addr(m_dm_mrf_bram_addr[0]),
    .bram_wrdata(m_dm_mrf_bram_wrdata[0]),
    .bram_en(m_dm_mrf_bram_en[0]),
    .bram_we(m_dm_mrf_bram_we[0])
  );

  // Datamover for mrf1
  axi2bram_datamover #(
    .AXI_ADDRWIDTH (DDR4_ADDRWIDTH),
    .BRAM_ADDRWIDTH(MRF_ADDRWIDTH),
    .DATAWIDTH     (MRF_DATAWIDTH)
  ) axi2bram_datamover_mrf1_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(m_dm_mrf_start[1]),
    .src_axi_addr_i(m_dm_mrf_src_axi_addr[1]),
    .dst_bram_addr_i(m_dm_mrf_dst_bram_addr[1]),
    .byte_to_trans_i(m_dm_mrf_byte_to_trans[1]),
    .done_o(m_dm_mrf_done[1]),
    .m_axi_araddr(m_dm_mrf_m_axi_araddr[1]),
    .m_axi_arburst(m_dm_mrf_m_axi_arburst[1]),
    .m_axi_arcache(m_dm_mrf_m_axi_arcache[1]),
    .m_axi_arlen(m_dm_mrf_m_axi_arlen[1]),
    .m_axi_arlock(m_dm_mrf_m_axi_arlock[1]),
    .m_axi_arprot(m_dm_mrf_m_axi_arprot[1]),
    .m_axi_arsize(m_dm_mrf_m_axi_arsize[1]),
    .m_axi_arvalid(m_dm_mrf_m_axi_arvalid[1]),
    .m_axi_arready(m_dm_mrf_m_axi_arready[1]),
    .m_axi_rdata(m_dm_mrf_m_axi_rdata[1]),
    .m_axi_rlast(m_dm_mrf_m_axi_rlast[1]),
    .m_axi_rresp(m_dm_mrf_m_axi_rresp[1]),
    .m_axi_rvalid(m_dm_mrf_m_axi_rvalid[1]),
    .m_axi_rready(m_dm_mrf_m_axi_rready[1]),
    .bram_addr(m_dm_mrf_bram_addr[1]),
    .bram_wrdata(m_dm_mrf_bram_wrdata[1]),
    .bram_en(m_dm_mrf_bram_en[1]),
    .bram_we(m_dm_mrf_bram_we[1])
  );

  // Datamover for mrf2
  axi2bram_datamover #(
    .AXI_ADDRWIDTH (DDR4_ADDRWIDTH),
    .BRAM_ADDRWIDTH(MRF_ADDRWIDTH),
    .DATAWIDTH     (MRF_DATAWIDTH)
  ) axi2bram_datamover_mrf2_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(m_dm_mrf_start[2]),
    .src_axi_addr_i(m_dm_mrf_src_axi_addr[2]),
    .dst_bram_addr_i(m_dm_mrf_dst_bram_addr[2]),
    .byte_to_trans_i(m_dm_mrf_byte_to_trans[2]),
    .done_o(m_dm_mrf_done[2]),
    .m_axi_araddr(m_dm_mrf_m_axi_araddr[2]),
    .m_axi_arburst(m_dm_mrf_m_axi_arburst[2]),
    .m_axi_arcache(m_dm_mrf_m_axi_arcache[2]),
    .m_axi_arlen(m_dm_mrf_m_axi_arlen[2]),
    .m_axi_arlock(m_dm_mrf_m_axi_arlock[2]),
    .m_axi_arprot(m_dm_mrf_m_axi_arprot[2]),
    .m_axi_arsize(m_dm_mrf_m_axi_arsize[2]),
    .m_axi_arvalid(m_dm_mrf_m_axi_arvalid[2]),
    .m_axi_arready(m_dm_mrf_m_axi_arready[2]),
    .m_axi_rdata(m_dm_mrf_m_axi_rdata[2]),
    .m_axi_rlast(m_dm_mrf_m_axi_rlast[2]),
    .m_axi_rresp(m_dm_mrf_m_axi_rresp[2]),
    .m_axi_rvalid(m_dm_mrf_m_axi_rvalid[2]),
    .m_axi_rready(m_dm_mrf_m_axi_rready[2]),
    .bram_addr(m_dm_mrf_bram_addr[2]),
    .bram_wrdata(m_dm_mrf_bram_wrdata[2]),
    .bram_en(m_dm_mrf_bram_en[2]),
    .bram_we(m_dm_mrf_bram_we[2])
  );

  // Datamover for mrf3
  axi2bram_datamover #(
    .AXI_ADDRWIDTH (DDR4_ADDRWIDTH),
    .BRAM_ADDRWIDTH(MRF_ADDRWIDTH),
    .DATAWIDTH     (MRF_DATAWIDTH)
  ) axi2bram_datamover_mrf3_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(m_dm_mrf_start[3]),
    .src_axi_addr_i(m_dm_mrf_src_axi_addr[3]),
    .dst_bram_addr_i(m_dm_mrf_dst_bram_addr[3]),
    .byte_to_trans_i(m_dm_mrf_byte_to_trans[3]),
    .done_o(m_dm_mrf_done[3]),
    .m_axi_araddr(m_dm_mrf_m_axi_araddr[3]),
    .m_axi_arburst(m_dm_mrf_m_axi_arburst[3]),
    .m_axi_arcache(m_dm_mrf_m_axi_arcache[3]),
    .m_axi_arlen(m_dm_mrf_m_axi_arlen[3]),
    .m_axi_arlock(m_dm_mrf_m_axi_arlock[3]),
    .m_axi_arprot(m_dm_mrf_m_axi_arprot[3]),
    .m_axi_arsize(m_dm_mrf_m_axi_arsize[3]),
    .m_axi_arvalid(m_dm_mrf_m_axi_arvalid[3]),
    .m_axi_arready(m_dm_mrf_m_axi_arready[3]),
    .m_axi_rdata(m_dm_mrf_m_axi_rdata[3]),
    .m_axi_rlast(m_dm_mrf_m_axi_rlast[3]),
    .m_axi_rresp(m_dm_mrf_m_axi_rresp[3]),
    .m_axi_rvalid(m_dm_mrf_m_axi_rvalid[3]),
    .m_axi_rready(m_dm_mrf_m_axi_rready[3]),
    .bram_addr(m_dm_mrf_bram_addr[3]),
    .bram_wrdata(m_dm_mrf_bram_wrdata[3]),
    .bram_en(m_dm_mrf_bram_en[3]),
    .bram_we(m_dm_mrf_bram_we[3])
  );

  // Datamover for vrf_ldr (AXI to BRAM)
  axi2bram_datamover #(
    .AXI_ADDRWIDTH (DDR4_ADDRWIDTH),
    .BRAM_ADDRWIDTH(VRF_ADDRWIDTH),
    .DATAWIDTH     (VRF_DATAWIDTH)
  ) axi2bram_datamover_vrf_ldr_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(m_dm_vrf_ldr_start),
    .src_axi_addr_i(m_dm_vrf_ldr_src_axi_addr),
    .dst_bram_addr_i(m_dm_vrf_ldr_dst_bram_addr),
    .byte_to_trans_i(m_dm_vrf_ldr_byte_to_trans),
    .done_o(m_dm_vrf_ldr_done),
    .m_axi_araddr(m_dm_vrf_ldr_m_axi_araddr),
    .m_axi_arburst(m_dm_vrf_ldr_m_axi_arburst),
    .m_axi_arcache(m_dm_vrf_ldr_m_axi_arcache),
    .m_axi_arlen(m_dm_vrf_ldr_m_axi_arlen),
    .m_axi_arlock(m_dm_vrf_ldr_m_axi_arlock),
    .m_axi_arprot(m_dm_vrf_ldr_m_axi_arprot),
    .m_axi_arsize(m_dm_vrf_ldr_m_axi_arsize),
    .m_axi_arvalid(m_dm_vrf_ldr_m_axi_arvalid),
    .m_axi_arready(m_dm_vrf_ldr_m_axi_arready),
    .m_axi_rdata(m_dm_vrf_ldr_m_axi_rdata),
    .m_axi_rlast(m_dm_vrf_ldr_m_axi_rlast),
    .m_axi_rresp(m_dm_vrf_ldr_m_axi_rresp),
    .m_axi_rvalid(m_dm_vrf_ldr_m_axi_rvalid),
    .m_axi_rready(m_dm_vrf_ldr_m_axi_rready),
    .bram_addr(vrf_ldr_bram_addr),
    .bram_wrdata(vrf_ldr_bram_wrdata),
    .bram_en(vrf_ldr_bram_en),
    .bram_we(vrf_ldr_bram_we)
  );

  // Datamover for vrf_ldr (BRAM to Arbiter)
  bram2arbiter_datamover #(
    .BRAM_ADDRWIDTH(VRF_ADDRWIDTH),
    .DATAWIDTH     (VRF_DATAWIDTH)
  ) bram2arbiter_datamover_vrf_ldr_inst (
    .clk(clk),
    .rst_n(rst_n),
    .full_o(m_dm_vrf_ldr_full_o),
    .done_o(m_dm_vrf_ldr_done_o),
    .bram_addr(vrf_ldr_bram_addr),
    .bram_wrdata(vrf_ldr_bram_wrdata),
    .bram_en(vrf_ldr_bram_en),
    .bram_we(vrf_ldr_bram_we),
    .wr_req(m_dm_vrf_ldr_wr_req),
    .wr_gnt(m_dm_vrf_ldr_wr_gnt),
    .wr_addr(m_dm_vrf_ldr_wr_addr),
    .wr_data(m_dm_vrf_ldr_wr_data)
  );

endmodule
