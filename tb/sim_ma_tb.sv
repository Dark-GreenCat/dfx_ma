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

  // AXI4 ports for mrf0 to mrf3
  logic [               0:3][DDR4_ADDRWIDTH-1:0] m_dm_mrf_m_axi_araddr;
  logic [               0:3][               1:0] m_dm_mrf_m_axi_arburst;
  logic [               0:3][               3:0] m_dm_mrf_m_axi_arcache;
  logic [               0:3][               7:0] m_dm_mrf_m_axi_arlen;
  logic [               0:3]                     m_dm_mrf_m_axi_arlock;
  logic [               0:3][               2:0] m_dm_mrf_m_axi_arprot;
  logic [               0:3][               2:0] m_dm_mrf_m_axi_arsize;
  logic [               0:3]                     m_dm_mrf_m_axi_arvalid;
  logic [               0:3]                     m_dm_mrf_m_axi_arready;
  logic [               0:3][ MRF_DATAWIDTH-1:0] m_dm_mrf_m_axi_rdata;
  logic [               0:3]                     m_dm_mrf_m_axi_rlast;
  logic [               0:3][               1:0] m_dm_mrf_m_axi_rresp;
  logic [               0:3]                     m_dm_mrf_m_axi_rvalid;
  logic [               0:3]                     m_dm_mrf_m_axi_rready;

  // BRAM ports for mrf0 to mrf3
  logic [               0:3][ MRF_ADDRWIDTH-1:0] m_dm_mrf_bram_addr;
  logic [               0:3][ MRF_DATAWIDTH-1:0] m_dm_mrf_bram_wrdata;
  logic [               0:3]                     m_dm_mrf_bram_en;
  logic [               0:3]                     m_dm_mrf_bram_we;

  // AXI4 ports for vrf_ldr
  logic [DDR4_ADDRWIDTH-1:0]                     m_dm_vrf_ldr_m_axi_araddr;
  logic [               1:0]                     m_dm_vrf_ldr_m_axi_arburst;
  logic [               3:0]                     m_dm_vrf_ldr_m_axi_arcache;
  logic [               7:0]                     m_dm_vrf_ldr_m_axi_arlen;
  logic                                          m_dm_vrf_ldr_m_axi_arlock;
  logic [               2:0]                     m_dm_vrf_ldr_m_axi_arprot;
  logic [               2:0]                     m_dm_vrf_ldr_m_axi_arsize;
  logic                                          m_dm_vrf_ldr_m_axi_arvalid;
  logic                                          m_dm_vrf_ldr_m_axi_arready;
  logic [ VRF_DATAWIDTH-1:0]                     m_dm_vrf_ldr_m_axi_rdata;
  logic                                          m_dm_vrf_ldr_m_axi_rlast;
  logic [               1:0]                     m_dm_vrf_ldr_m_axi_rresp;
  logic                                          m_dm_vrf_ldr_m_axi_rvalid;
  logic                                          m_dm_vrf_ldr_m_axi_rready;

  // Arbiter ports for vrf_ldr
  logic                                          m_dm_vrf_ldr_full_o;
  logic                                          m_dm_vrf_ldr_wr_req;
  logic                                          m_dm_vrf_ldr_wr_gnt;
  logic [ VRF_ADDRWIDTH-1:0]                     m_dm_vrf_ldr_wr_addr;
  logic [ VRF_DATAWIDTH-1:0]                     m_dm_vrf_ldr_wr_data;

  logic                                          m_dm_vrf_str_rd_req;
  logic                                          m_dm_vrf_str_rd_gnt;
  logic [ VRF_ADDRWIDTH-1:0]                     m_dm_vrf_str_rd_addr;
  logic [ VRF_DATAWIDTH-1:0]                     m_dm_vrf_str_rd_data;

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
    .arf_dout_i(arf_dout_i),
    .m_dm_mrf_m_axi_araddr(m_dm_mrf_m_axi_araddr),
    .m_dm_mrf_m_axi_arburst(m_dm_mrf_m_axi_arburst),
    .m_dm_mrf_m_axi_arcache(m_dm_mrf_m_axi_arcache),
    .m_dm_mrf_m_axi_arlen(m_dm_mrf_m_axi_arlen),
    .m_dm_mrf_m_axi_arlock(m_dm_mrf_m_axi_arlock),
    .m_dm_mrf_m_axi_arprot(m_dm_mrf_m_axi_arprot),
    .m_dm_mrf_m_axi_arsize(m_dm_mrf_m_axi_arsize),
    .m_dm_mrf_m_axi_arvalid(m_dm_mrf_m_axi_arvalid),
    .m_dm_mrf_m_axi_arready(m_dm_mrf_m_axi_arready),
    .m_dm_mrf_m_axi_rdata(m_dm_mrf_m_axi_rdata),
    .m_dm_mrf_m_axi_rlast(m_dm_mrf_m_axi_rlast),
    .m_dm_mrf_m_axi_rresp(m_dm_mrf_m_axi_rresp),
    .m_dm_mrf_m_axi_rvalid(m_dm_mrf_m_axi_rvalid),
    .m_dm_mrf_m_axi_rready(m_dm_mrf_m_axi_rready),
    .m_dm_mrf_bram_addr(m_dm_mrf_bram_addr),
    .m_dm_mrf_bram_wrdata(m_dm_mrf_bram_wrdata),
    .m_dm_mrf_bram_en(m_dm_mrf_bram_en),
    .m_dm_mrf_bram_we(m_dm_mrf_bram_we),
    .m_dm_vrf_ldr_m_axi_araddr(m_dm_vrf_ldr_m_axi_araddr),
    .m_dm_vrf_ldr_m_axi_arburst(m_dm_vrf_ldr_m_axi_arburst),
    .m_dm_vrf_ldr_m_axi_arcache(m_dm_vrf_ldr_m_axi_arcache),
    .m_dm_vrf_ldr_m_axi_arlen(m_dm_vrf_ldr_m_axi_arlen),
    .m_dm_vrf_ldr_m_axi_arlock(m_dm_vrf_ldr_m_axi_arlock),
    .m_dm_vrf_ldr_m_axi_arprot(m_dm_vrf_ldr_m_axi_arprot),
    .m_dm_vrf_ldr_m_axi_arsize(m_dm_vrf_ldr_m_axi_arsize),
    .m_dm_vrf_ldr_m_axi_arvalid(m_dm_vrf_ldr_m_axi_arvalid),
    .m_dm_vrf_ldr_m_axi_arready(m_dm_vrf_ldr_m_axi_arready),
    .m_dm_vrf_ldr_m_axi_rdata(m_dm_vrf_ldr_m_axi_rdata),
    .m_dm_vrf_ldr_m_axi_rlast(m_dm_vrf_ldr_m_axi_rlast),
    .m_dm_vrf_ldr_m_axi_rresp(m_dm_vrf_ldr_m_axi_rresp),
    .m_dm_vrf_ldr_m_axi_rvalid(m_dm_vrf_ldr_m_axi_rvalid),
    .m_dm_vrf_ldr_m_axi_rready(m_dm_vrf_ldr_m_axi_rready),
    .m_dm_vrf_ldr_full_o(m_dm_vrf_ldr_full_o),
    .m_dm_vrf_ldr_wr_req(m_dm_vrf_ldr_wr_req),
    .m_dm_vrf_ldr_wr_gnt(m_dm_vrf_ldr_wr_gnt),
    .m_dm_vrf_ldr_wr_addr(m_dm_vrf_ldr_wr_addr),
    .m_dm_vrf_ldr_wr_data(m_dm_vrf_ldr_wr_data),
    .m_dm_vrf_str_rd_req(m_dm_vrf_str_rd_req),
    .m_dm_vrf_str_rd_gnt(m_dm_vrf_str_rd_gnt),
    .m_dm_vrf_str_rd_addr(m_dm_vrf_str_rd_addr),
    .m_dm_vrf_str_rd_data(m_dm_vrf_str_rd_data)
  );

  // ARF RAM instance
  ram_1p #(
    .DATAWIDTH (ARF_DATAWIDTH),
    .DEPTH     (32),
    .MEMFILE   ("tb/init.mem"),
    .READ_DELAY(2)
  ) ram_1p_arf_inst (
    .clk (clk),
    .en  (arf_en_o),
    .we  (arf_we_o),
    .addr(arf_addr_o),
    .din ('0),
    .dout(arf_dout_i)
  );

  // MRF BRAM instances
  generate
    for (genvar i = 0; i < 4; i++) begin : mrf_bram
      ram_1p #(
        .DATAWIDTH (MRF_DATAWIDTH),
        .DEPTH     (64),
        .MEMFILE   (""),
        .READ_DELAY(1)
      ) ram_1p_mrf_inst (
        .clk (clk),
        .en  (m_dm_mrf_bram_en[i]),
        .we  (m_dm_mrf_bram_we[i]),
        .addr(m_dm_mrf_bram_addr[i]),
        .din (m_dm_mrf_bram_wrdata[i]),
        .dout()
      );
    end
  endgenerate
  logic [9:0] arbiter_bram_a_addr;
  logic [1023:0] arbiter_bram_a_dout;
  logic [1023:0] arbiter_bram_a_din;
  logic arbiter_bram_a_en;
  logic arbiter_bram_a_we;
  logic [9:0] arbiter_bram_b_addr;
  logic [1023:0] arbiter_bram_b_dout;
  logic [1023:0] arbiter_bram_b_din;
  logic arbiter_bram_b_en;
  logic arbiter_bram_b_we;

  arbiter #(
    .VRF_ADDR_WIDTH(10),
    .VRF_DATA_WIDTH(1024)
  ) arbiter_inst (
    .clk(clk),
    .rst_n(rst_n),
    .bram_a_addr_o(arbiter_bram_a_addr),
    .bram_a_dout_i(arbiter_bram_a_dout),
    .bram_a_din_o(arbiter_bram_a_din),
    .bram_a_en_o(arbiter_bram_a_en),
    .bram_a_we_o(arbiter_bram_a_we),
    .bram_b_addr_o(arbiter_bram_b_addr),
    .bram_b_dout_i(arbiter_bram_b_dout),
    .bram_b_din_o(arbiter_bram_b_din),
    .bram_b_en_o(arbiter_bram_b_en),
    .bram_b_we_o(arbiter_bram_b_we),

    .ma_v_src_addr_i(m_dm_vrf_str_rd_addr),
    .ma_v_src_data_o(m_dm_vrf_str_rd_data),
    .ma_read_req_i  (m_dm_vrf_str_rd_req),
    .ma_read_gnt_o  (m_dm_vrf_str_rd_gnt),

    .ma_v_res_addr_i(m_dm_vrf_ldr_wr_addr),
    .ma_v_res_data_i(m_dm_vrf_ldr_wr_data),
    .ma_write_req_i (m_dm_vrf_ldr_wr_req),
    .ma_write_gnt_o (m_dm_vrf_ldr_wr_gnt)
  );

  // VRF RAM instance
  ram_2p #(
    .DATAWIDTH_A(VRF_DATAWIDTH),
    .DEPTH_A    (1024),
    .DATAWIDTH_B(VRF_DATAWIDTH),
    .DEPTH_B    (1024),
    .MEMFILE    ("tb/init.mem"),
    .READ_DELAY (2)
  ) vrf_bram (
    .clk_a (clk),
    .en_a  (arbiter_bram_a_en),
    .we_a  (arbiter_bram_a_we),
    .addr_a(arbiter_bram_a_addr),
    .din_a (arbiter_bram_a_din),
    .dout_a(arbiter_bram_a_dout),
    .clk_b (clk),
    .en_b  (arbiter_bram_b_en),
    .we_b  (arbiter_bram_b_we),
    .addr_b(arbiter_bram_b_addr),
    .din_b (arbiter_bram_b_din),
    .dout_b(arbiter_bram_b_dout)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Reset and calibration
  initial begin
    ma_ddr4_calib_complete_i = 4'hF;
    rst_n                    = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (20) @(posedge clk);
    ma_ddr4_calib_complete_i = 4'b1111;
  end

  // AXI slave emulation for MRF
  logic [0:3][7:0] mrf_axi_transfer_count;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m_dm_mrf_m_axi_arready <= 0;
      m_dm_mrf_m_axi_rdata   <= 0;
      m_dm_mrf_m_axi_rlast   <= 0;
      m_dm_mrf_m_axi_rresp   <= 0;
      m_dm_mrf_m_axi_rvalid  <= 0;
      mrf_axi_transfer_count <= 0;
    end else begin
      for (int i = 0; i < 4; i++) begin
        if (m_dm_mrf_m_axi_arvalid[i] && !m_dm_mrf_m_axi_arready[i]) begin
          m_dm_mrf_m_axi_arready[i] <= 1;
          @(posedge clk);
          m_dm_mrf_m_axi_arready[i] <= 0;
          mrf_axi_transfer_count[i] <= 0;
          repeat (2) @(posedge clk);
          while (mrf_axi_transfer_count[i] <= m_dm_mrf_m_axi_arlen[i]) begin
            if (m_dm_mrf_m_axi_rready[i]) begin
              m_dm_mrf_m_axi_rvalid[i]  <= 1;
              m_dm_mrf_m_axi_rdata[i]   <= mrf_axi_transfer_count[i];
              m_dm_mrf_m_axi_rresp[i]   <= 2'b00;
              m_dm_mrf_m_axi_rlast[i]   <= (mrf_axi_transfer_count[i] == m_dm_mrf_m_axi_arlen[i]);
              mrf_axi_transfer_count[i] <= mrf_axi_transfer_count[i] + 1;
              @(posedge clk);
            end
          end
          m_dm_mrf_m_axi_rvalid[i] <= 0;
          m_dm_mrf_m_axi_rlast[i]  <= 0;
        end
      end
    end
  end

  // AXI slave emulation for VRF load
  logic [7:0] vrf_ldr_axi_transfer_count;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m_dm_vrf_ldr_m_axi_arready <= 0;
      m_dm_vrf_ldr_m_axi_rdata   <= 0;
      m_dm_vrf_ldr_m_axi_rlast   <= 0;
      m_dm_vrf_ldr_m_axi_rresp   <= 0;
      m_dm_vrf_ldr_m_axi_rvalid  <= 0;
      vrf_ldr_axi_transfer_count <= 0;
    end else begin
      if (m_dm_vrf_ldr_m_axi_arvalid && !m_dm_vrf_ldr_m_axi_arready) begin
        m_dm_vrf_ldr_m_axi_arready <= 1;
        @(posedge clk);
        m_dm_vrf_ldr_m_axi_arready <= 0;
        vrf_ldr_axi_transfer_count <= 0;
        repeat (2) @(posedge clk);
        while (vrf_ldr_axi_transfer_count <= m_dm_vrf_ldr_m_axi_arlen) begin
          if (m_dm_vrf_ldr_m_axi_rready) begin
            m_dm_vrf_ldr_m_axi_rvalid  <= 1;
            m_dm_vrf_ldr_m_axi_rdata   <= vrf_ldr_axi_transfer_count + 5;
            m_dm_vrf_ldr_m_axi_rresp   <= 2'b00;
            m_dm_vrf_ldr_m_axi_rlast   <= (vrf_ldr_axi_transfer_count == m_dm_vrf_ldr_m_axi_arlen);
            vrf_ldr_axi_transfer_count <= vrf_ldr_axi_transfer_count + 1;
            @(posedge clk);
          end
        end
        m_dm_vrf_ldr_m_axi_rvalid <= 0;
        m_dm_vrf_ldr_m_axi_rlast  <= 0;
      end
    end
  end


  // Test case
  initial begin
    ma_start_i           = 0;
    ma_select_v_m_i      = 0;
    ma_v_load_or_store_i = 0;
    ma_v_m_reg_i         = 0;
    ma_a_reg_i           = 0;
    ma_a_offset_i        = 0;
    @(posedge ma_ddr4_linkup_o);

    // Test 1: LDR.V V2, 0x100(A4)
    @(posedge clk);
    ma_start_i           = 1;
    ma_select_v_m_i      = 0;
    ma_v_load_or_store_i = 0;
    ma_v_m_reg_i         = 2;
    ma_a_reg_i           = 4;
    ma_a_offset_i        = 16'h100;
    @(posedge clk);
    ma_start_i = 0;
    @(posedge ma_done_o);

    // Test 2: STR.V V3, 0x100(A4)
    @(posedge clk);
    ma_start_i           = 1;
    ma_select_v_m_i      = 0;
    ma_v_load_or_store_i = 1;
    ma_v_m_reg_i         = 3;
    ma_a_reg_i           = 4;
    ma_a_offset_i        = 16'h100;
    @(posedge clk);
    ma_start_i = 0;
    // @(posedge ma_done_o);

    repeat (300) @(posedge clk);
    $finish;
  end

  // Timeout
  initial begin
    repeat (1000) @(posedge clk);
    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("sim_ma_tb.vcd");
    $dumpvars(0, sim_ma_tb);
  end

endmodule
