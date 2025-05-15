`timescale 1ns / 1ps

module sim_ma_tb;

  localparam CLK_PERIOD = 10;

  // Parameters
  localparam NUM_OF_DDR4 = 4;
  localparam DDR4_ADDRWIDTH = 36;
  localparam ARF_ADDRWIDTH = 5;
  localparam ARF_DATAWIDTH = DDR4_ADDRWIDTH;
  localparam VRF_ADDRWIDTH = 10;
  localparam VRF_DATAWIDTH = 1024;
  localparam MRF_ADDRWIDTH = 6;
  localparam MRF_DATAWIDTH = 1024;

  // Ports
  logic                                          clk;
  logic                                          rst_n;
  logic [   NUM_OF_DDR4-1:0]                     ma_ddr4_calib_complete_i;
  logic                                          ma_ddr4_linkup_o;
  logic                                          ma_start_i;
  logic                                          ma_select_v_m_i;
  logic                                          ma_v_load_or_store_i;
  logic [ VRF_ADDRWIDTH-1:0]                     ma_v_m_reg_i;
  logic [ ARF_ADDRWIDTH-1:0]                     ma_a_reg_i;
  logic [ ARF_DATAWIDTH-1:0]                     ma_a_offset_i;
  logic                                          ma_done_o;
  logic                                          arf_en_o;
  logic                                          arf_we_o;
  logic [ ARF_ADDRWIDTH-1:0]                     arf_addr_o;
  logic [ ARF_DATAWIDTH-1:0]                     arf_dout_i;

  // Instantiate ma module
  ma #(
    .NUM_OF_DDR4   (NUM_OF_DDR4),
    .DDR4_ADDRWIDTH(DDR4_ADDRWIDTH),
    .ARF_ADDRWIDTH (ARF_ADDRWIDTH),
    .ARF_DATAWIDTH (ARF_DATAWIDTH),
    .VRF_ADDRWIDTH (VRF_ADDRWIDTH),
    .VRF_DATAWIDTH (VRF_DATAWIDTH),
    .MRF_ADDRWIDTH (MRF_ADDRWIDTH),
    .MRF_DATAWIDTH (MRF_DATAWIDTH)
  ) ma_inst (
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
    .arf_dout_i(arf_dout_i)
  );

  ram_1p # (
    .DATAWIDTH(ARF_DATAWIDTH),
    .DEPTH(32),
    .MEMFILE("tb/init.mem"),
    .READ_DELAY(2)
  )
  ram_1p_inst (
    .clk(clk),
    .en(arf_en_o),
    .we(arf_we_o),
    .addr(arf_addr_o),
    .din(),
    .dout(arf_dout_i)
  );

  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  initial begin
    ma_ddr4_calib_complete_i = 4'hF;
    rst_n                    = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (20) @(posedge clk);
    ma_ddr4_calib_complete_i = 1;
  end

  initial begin
    ma_start_i           = 0;
    ma_select_v_m_i      = 0;
    ma_v_load_or_store_i = 0;
    ma_v_m_reg_i         = 0;
    ma_a_reg_i           = 0;
    ma_a_offset_i        = 0;
    @(posedge ma_ddr4_linkup_o);

    // Test 1: LDR.V V2, 0x100(A4)
    ma_start_i           = 1;
    ma_select_v_m_i      = 0;
    ma_v_load_or_store_i = 0;
    ma_v_m_reg_i         = 2;
    ma_a_reg_i           = 4;
    ma_a_offset_i        = 16'h100;
    @(posedge clk);
    ma_start_i = 0;
    @(posedge ma_done_o);

    repeat (5) @(posedge clk);
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $finish;
  end

  initial begin
    $dumpfile("sim_ma_tb.vcd");
    $dumpvars(0, sim_ma_tb);
  end

endmodule
