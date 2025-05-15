`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2025 04:25:14 PM
// Design Name: 
// Module Name: arbiter_rr
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// VPU > MPU > MA > ROUTER
// VPU_READ > VPU_WRITE > MPU_READ > MPU_WRITE...
// BRAM A > BRAM B
// VPU_READ: Là được dùng cả 2 port.

module arbiter #(
  parameter VRF_ADDR_WIDTH = 10,
  parameter VRF_DATA_WIDTH = 1024
) (
  input clk,
  input rst_n,

  //BRAM port A
  output logic [VRF_ADDR_WIDTH-1:0] bram_a_addr_o,
  input        [VRF_DATA_WIDTH-1:0] bram_a_dout_i,
  output logic [VRF_DATA_WIDTH-1:0] bram_a_din_o,
  output logic                      bram_a_en_o,
  output logic                      bram_a_we_o,

  //BRAM port B
  output logic [VRF_ADDR_WIDTH-1:0] bram_b_addr_o,
  input        [VRF_DATA_WIDTH-1:0] bram_b_dout_i,
  output logic [VRF_DATA_WIDTH-1:0] bram_b_din_o,
  output logic                      bram_b_en_o,
  output logic                      bram_b_we_o,

  // VPU interface
  input        [VRF_ADDR_WIDTH-1:0] vpu_v_src1_addr_i,
  output logic [VRF_DATA_WIDTH-1:0] vpu_v_src1_data_o,
  input        [VRF_ADDR_WIDTH-1:0] vpu_v_src2_addr_i,
  output logic [VRF_DATA_WIDTH-1:0] vpu_v_src2_data_o,
  input                             vpu_read_req_i,
  output logic                      vpu_read_gnt_o,

  input        [VRF_ADDR_WIDTH-1:0] vpu_v_res_addr_i,
  input        [VRF_DATA_WIDTH-1:0] vpu_v_res_data_i,
  input                             vpu_write_req_i,
  output logic                      vpu_write_gnt_o,

  // MPU interface
  input        [VRF_ADDR_WIDTH-1:0] mpu_v_src_addr_i,
  output logic [VRF_DATA_WIDTH-1:0] mpu_v_src_data_o,
  input                             mpu_read_req_i,
  output logic                      mpu_read_gnt_o,

  input        [VRF_ADDR_WIDTH-1:0] mpu_v_res_addr_i,
  input        [VRF_DATA_WIDTH-1:0] mpu_v_res_data_i,
  input                             mpu_write_req_i,
  output logic                      mpu_write_gnt_o,

  // MA interface
  input        [VRF_ADDR_WIDTH-1:0] ma_v_src_addr_i,
  output logic [VRF_DATA_WIDTH-1:0] ma_v_src_data_o,
  input                             ma_read_req_i,
  output logic                      ma_read_gnt_o,

  input        [VRF_ADDR_WIDTH-1:0] ma_v_res_addr_i,
  input        [VRF_DATA_WIDTH-1:0] ma_v_res_data_i,
  input                             ma_write_req_i,
  output logic                      ma_write_gnt_o,

  // Router interface
  input        [VRF_ADDR_WIDTH-1:0] router_v_src_addr_i,
  output logic [VRF_DATA_WIDTH-1:0] router_v_src_data_o,
  input                             router_read_req_i,
  output logic                      router_read_gnt_o,

  input        [VRF_ADDR_WIDTH-1:0] router_v_res_addr_i,
  input        [VRF_DATA_WIDTH-1:0] router_v_res_data_i,
  input                             router_write_req_i,
  output logic                      router_write_gnt_o
);
  typedef enum logic [2:0] {
    NONE   = 3'b000,
    VPU    = 3'b100,
    MPU    = 3'b101,
    MA     = 3'b110,
    ROUTER = 3'b111
  } user_t;
  user_t port_a_used_by;
  user_t next_port_a_used_by;
  user_t port_b_used_by;
  user_t next_port_b_used_by;
  logic  vpu_req;
  logic  mpu_req;
  logic  ma_req;
  logic  router_req;
  assign vpu_req    = vpu_read_req_i | vpu_write_req_i;
  assign mpu_req    = mpu_read_req_i | mpu_write_req_i;
  assign ma_req     = ma_read_req_i | ma_write_req_i;
  assign router_req = router_read_req_i | router_write_req_i;

  always_comb begin
    // next_port_a_used_by = port_a_used_by;
    case (port_a_used_by)
      NONE: begin
        if (vpu_read_req_i) begin
          if (port_b_used_by == NONE) begin
            next_port_a_used_by = VPU;
          end else begin
            next_port_a_used_by = NONE;
          end
        end else if (vpu_write_req_i && port_b_used_by != VPU) begin
          next_port_a_used_by = VPU;
        end else if (mpu_req && port_b_used_by != MPU) begin
          next_port_a_used_by = MPU;
        end else if (ma_req && port_b_used_by != MA) begin
          next_port_a_used_by = MA;
        end else if (router_req && port_b_used_by != ROUTER) begin
          next_port_a_used_by = ROUTER;
        end else begin
          next_port_a_used_by = NONE;
        end
      end
      VPU: begin
        if (!(vpu_read_req_i || vpu_write_req_i)) begin
          next_port_a_used_by = NONE;
        end else begin
          next_port_a_used_by = VPU;
        end
      end
      MPU: begin
        if (!mpu_req) begin
          next_port_a_used_by = NONE;
        end else begin
          next_port_a_used_by = MPU;
        end
      end
      MA: begin
        if (!ma_req) begin
          next_port_a_used_by = NONE;
        end else begin
          next_port_a_used_by = MA;
        end
      end
      ROUTER: begin
        if (!router_req) begin
          next_port_a_used_by = NONE;
        end else begin
          next_port_a_used_by = ROUTER;
        end
      end
      default: begin
        next_port_a_used_by = NONE;
      end
    endcase
  end

  always_comb begin
    // next_port_b_used_by = port_b_used_by;
    case (port_b_used_by)
      NONE: begin
        if (vpu_read_req_i) begin
          if (port_a_used_by == NONE) begin
            next_port_b_used_by = VPU;
          end else begin
            next_port_b_used_by = NONE;
          end
        end else if (vpu_write_req_i && next_port_a_used_by != VPU) begin
          next_port_b_used_by = VPU;
        end else if (mpu_req && next_port_a_used_by != MPU) begin
          next_port_b_used_by = MPU;
        end else if (ma_req && next_port_a_used_by != MA) begin
          next_port_b_used_by = MA;
        end else if (router_req && next_port_a_used_by != ROUTER) begin
          next_port_b_used_by = ROUTER;
        end else begin
          next_port_b_used_by = NONE;
        end
      end
      VPU: begin
        if (!(vpu_read_req_i || vpu_write_req_i)) begin
          next_port_b_used_by = NONE;
        end else begin
          next_port_b_used_by = VPU;
        end
      end
      MPU: begin
        if (!mpu_req) begin
          next_port_b_used_by = NONE;
        end else begin
          next_port_b_used_by = MPU;
        end
      end
      MA: begin
        if (!ma_req) begin
          next_port_b_used_by = NONE;
        end else begin
          next_port_b_used_by = MA;
        end
      end
      ROUTER: begin
        if (!router_req) begin
          next_port_b_used_by = NONE;
        end else begin
          next_port_b_used_by = ROUTER;
        end
      end
      default: begin
        next_port_b_used_by = NONE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      port_a_used_by <= NONE;
      port_b_used_by <= NONE;
    end else begin
      port_a_used_by <= next_port_a_used_by;
      port_b_used_by <= next_port_b_used_by;
    end
  end

  always_comb begin : Port_A_Control
    case (port_a_used_by)
      NONE: begin
        bram_a_addr_o = 0;
        bram_a_din_o  = 0;
        bram_a_en_o   = 0;
        bram_a_we_o   = 0;
        // vpu_v_src1_data_o = 0;
        // vpu_v_src2_data_o = 0;
        // mpu_v_src_data_o = 0;
        // ma_v_src_data_o = 0;
        // router_v_src_data_o = 0;
        // vpu_read_gnt_o = 0;
        // vpu_write_gnt_o = 0;
        // mpu_read_gnt_o = 0;
        // mpu_write_gnt_o = 0;
        // ma_read_gnt_o = 0;
        // ma_write_gnt_o = 0;
        // router_read_gnt_o = 0;
        // router_write_gnt_o = 0;
      end
      VPU: begin
        if (vpu_read_req_i) begin
          bram_a_addr_o = vpu_v_src1_addr_i;
          bram_a_din_o  = 0;
          bram_a_en_o   = 1;
          bram_a_we_o   = 0;
          // vpu_v_src1_data_o = bram_a_dout_i;
        end else if (vpu_write_req_i) begin
          bram_a_addr_o = vpu_v_res_addr_i;
          bram_a_din_o  = vpu_v_res_data_i;
          bram_a_en_o   = 1;
          bram_a_we_o   = 1;
          // vpu_v_src1_data_o = 0;
        end else begin
          bram_a_addr_o = 0;
          bram_a_din_o  = 0;
          bram_a_en_o   = 0;
          bram_a_we_o   = 0;
          // vpu_v_src1_data_o = 0;
        end
      end
      MPU: begin
        // vpu_v_src1_data_o = 0;
        if (mpu_read_req_i) begin
          bram_a_addr_o = mpu_v_src_addr_i;
          bram_a_din_o  = 0;
          bram_a_en_o   = 1;
          bram_a_we_o   = 0;
          // mpu_v_src_data_o = bram_a_dout_i;
          // mpu_read_gnt_o = 1;
          // mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          bram_a_addr_o = mpu_v_res_addr_i;
          bram_a_din_o  = mpu_v_res_data_i;
          bram_a_en_o   = 1;
          bram_a_we_o   = 1;
          // mpu_v_src_data_o = 0;
          // mpu_read_gnt_o = 0;
          // mpu_write_gnt_o = 1;
        end else begin
          bram_a_addr_o = 0;
          bram_a_din_o  = 0;
          bram_a_en_o   = 0;
          bram_a_we_o   = 0;
          // mpu_v_src_data_o = 0;
          // mpu_read_gnt_o = 0;
          // mpu_write_gnt_o = 0;
        end
      end
      MA: begin
        // vpu_v_src1_data_o = 0;
        if (ma_read_req_i) begin
          bram_a_addr_o = ma_v_src_addr_i;
          bram_a_din_o  = 0;
          bram_a_en_o   = 1;
          bram_a_we_o   = 0;
          // ma_v_src_data_o = bram_a_dout_i;
          // ma_read_gnt_o = 1;
          // ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          bram_a_addr_o = ma_v_res_addr_i;
          bram_a_din_o  = ma_v_res_data_i;
          bram_a_en_o   = 1;
          bram_a_we_o   = 1;
          // ma_v_src_data_o = 0;
          // ma_read_gnt_o = 0;
          // ma_write_gnt_o = 1;
        end else begin
          bram_a_addr_o = 0;
          bram_a_din_o  = 0;
          bram_a_en_o   = 0;
          bram_a_we_o   = 0;
          // ma_v_src_data_o = 0;
          // ma_read_gnt_o = 0;
          // ma_write_gnt_o = 0;
        end
      end
      ROUTER: begin
        // vpu_v_src1_data_o = 0;
        if (router_read_req_i) begin
          bram_a_addr_o = router_v_src_addr_i;
          bram_a_din_o  = 0;
          bram_a_en_o   = 1;
          bram_a_we_o   = 0;
          // router_v_src_data_o = bram_a_dout_i;
          // router_read_gnt_o = 1;
          // router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          bram_a_addr_o = router_v_res_addr_i;
          bram_a_din_o  = router_v_res_data_i;
          bram_a_en_o   = 1;
          bram_a_we_o   = 1;
          // router_v_src_data_o = 0;
          // router_read_gnt_o = 0;
          // router_write_gnt_o = 1;
        end else begin
          bram_a_addr_o = 0;
          bram_a_din_o  = 0;
          bram_a_en_o   = 0;
          bram_a_we_o   = 0;
          // router_v_src_data_o = 0;
          // router_read_gnt_o = 0;
          // router_write_gnt_o = 0;
        end
      end
      default: begin
        bram_a_addr_o = 0;
        bram_a_din_o  = 0;
        bram_a_en_o   = 0;
        bram_a_we_o   = 0;
        // vpu_v_src1_data_o = 0;
        // vpu_v_src2_data_o = 0;
        // mpu_v_src_data_o = 0;
        // ma_v_src_data_o = 0;
        // router_v_src_data_o = 0;
        // vpu_read_gnt_o = 0;
        // vpu_write_gnt_o = 0;
        // mpu_read_gnt_o = 0;
        // mpu_write_gnt_o = 0;
        // ma_read_gnt_o = 0;
        // ma_write_gnt_o = 0;
        // router_read_gnt_o = 0;
        // router_write_gnt_o = 0;
      end
    endcase
  end

  always_comb begin : Port_B_Control
    case (port_b_used_by)
      NONE: begin
        bram_b_addr_o = 0;
        bram_b_din_o  = 0;
        bram_b_en_o   = 0;
        bram_b_we_o   = 0;
        // vpu_v_src1_data_o = 0;
        // vpu_v_src2_data_o = 0;
        // mpu_v_src_data_o = 0;
        // ma_v_src_data_o = 0;
        // router_v_src_data_o = 0;
        // vpu_read_gnt_o = 0;
        // vpu_write_gnt_o = 0;
        // mpu_read_gnt_o = 0;
        // mpu_write_gnt_o = 0;
        // ma_read_gnt_o = 0;
        // ma_write_gnt_o = 0;
        // router_read_gnt_o = 0;
        // router_write_gnt_o = 0;
      end
      VPU: begin
        if (vpu_read_req_i) begin
          bram_b_addr_o = vpu_v_src2_addr_i;
          bram_b_din_o  = 0;
          bram_b_en_o   = 1;
          bram_b_we_o   = 0;
          // vpu_v_src2_data_o = bram_b_dout_i;
        end else if (vpu_write_req_i) begin
          bram_b_addr_o = vpu_v_res_addr_i;
          bram_b_din_o  = vpu_v_res_data_i;
          bram_b_en_o   = 1;
          bram_b_we_o   = 1;
          // vpu_v_src2_data_o = 0;
        end else begin
          bram_b_addr_o = 0;
          bram_b_din_o  = 0;
          bram_b_en_o   = 0;
          bram_b_we_o   = 0;
          // vpu_v_src2_data_o = 0;
        end
      end
      MPU: begin
        // vpu_v_src2_data_o = 0;
        if (mpu_read_req_i) begin
          bram_b_addr_o = mpu_v_src_addr_i;
          bram_b_din_o  = 0;
          bram_b_en_o   = 1;
          bram_b_we_o   = 0;
          // mpu_v_src_data_o = bram_b_dout_i;
          // mpu_read_gnt_o = 1;
          // mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          bram_b_addr_o = mpu_v_res_addr_i;
          bram_b_din_o  = mpu_v_res_data_i;
          bram_b_en_o   = 1;
          bram_b_we_o   = 1;
          // mpu_v_src_data_o = 0;
          // mpu_read_gnt_o = 0;
          // mpu_write_gnt_o = 1;
        end else begin
          bram_b_addr_o = 0;
          bram_b_din_o  = 0;
          bram_b_en_o   = 0;
          bram_b_we_o   = 0;
          // mpu_v_src_data_o = 0;
        end
      end
      MA: begin
        // vpu_v_src2_data_o = 0;
        if (ma_read_req_i) begin
          bram_b_addr_o = ma_v_src_addr_i;
          bram_b_din_o  = 0;
          bram_b_en_o   = 1;
          bram_b_we_o   = 0;
          // ma_v_src_data_o = bram_b_dout_i;
        end else if (ma_write_req_i) begin
          bram_b_addr_o = ma_v_res_addr_i;
          bram_b_din_o  = ma_v_res_data_i;
          bram_b_en_o   = 1;
          bram_b_we_o   = 1;
          // ma_v_src_data_o = 0;
        end else begin
          bram_b_addr_o = 0;
          bram_b_din_o  = 0;
          bram_b_en_o   = 0;
          bram_b_we_o   = 0;
          // ma_v_src_data_o = 0;
        end
      end
      ROUTER: begin
        // vpu_v_src2_data_o = 0;
        if (router_read_req_i) begin
          bram_b_addr_o = router_v_src_addr_i;
          bram_b_din_o  = 0;
          bram_b_en_o   = 1;
          bram_b_we_o   = 0;
          // router_v_src_data_o = bram_b_dout_i;
        end else if (router_write_req_i) begin
          bram_b_addr_o = router_v_res_addr_i;
          bram_b_din_o  = router_v_res_data_i;
          bram_b_en_o   = 1;
          bram_b_we_o   = 1;
          // router_v_src_data_o = 0;
        end else begin
          bram_b_addr_o = 0;
          bram_b_din_o  = 0;
          bram_b_en_o   = 0;
          bram_b_we_o   = 0;
          // router_v_src_data_o = 0;
        end
      end
      default: begin
        bram_b_addr_o = 0;
        bram_b_din_o  = 0;
        bram_b_en_o   = 0;
        bram_b_we_o   = 0;
        // vpu_v_src1_data_o = 0;
        // vpu_v_src2_data_o = 0;
        // mpu_v_src_data_o = 0;
        // ma_v_src_data_o = 0;
        // router_v_src_data_o = 0;
        // vpu_read_gnt_o = 0;
        // vpu_write_gnt_o = 0;
        // mpu_read_gnt_o = 0;
        // mpu_write_gnt_o = 0;
        // ma_read_gnt_o = 0;
        // ma_write_gnt_o = 0;
        // router_read_gnt_o = 0;
        // router_write_gnt_o = 0;
      end
    endcase
  end

  always_comb begin : Return_Grant
    case ({
      port_a_used_by, port_b_used_by
    })
      {
        NONE, NONE
      } : begin
        vpu_read_gnt_o      = 0;
        vpu_write_gnt_o     = 0;
        vpu_v_src1_data_o   = 0;
        vpu_v_src2_data_o   = 0;
        mpu_read_gnt_o      = 0;
        mpu_write_gnt_o     = 0;
        mpu_v_src_data_o    = 0;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        NONE, VPU
      } : begin
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o   = 0;
        vpu_v_src2_data_o   = bram_b_dout_i;
        mpu_read_gnt_o      = 0;
        mpu_write_gnt_o     = 0;
        mpu_v_src_data_o    = 0;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        NONE, MPU
      } : begin
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o    = bram_b_dout_i;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        NONE, MA
      } : begin
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_b_dout_i;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        NONE, ROUTER
      } : begin
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        ma_read_gnt_o     = 0;
        ma_write_gnt_o    = 0;
        ma_v_src_data_o   = 0;
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_b_dout_i;
      end
      {
        VPU, NONE
      } : begin
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o   = bram_a_dout_i;
        vpu_v_src2_data_o   = 0;
        mpu_read_gnt_o      = 0;
        mpu_write_gnt_o     = 0;
        mpu_v_src_data_o    = 0;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        VPU, VPU
      } : begin
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o   = bram_a_dout_i;
        vpu_v_src2_data_o   = bram_b_dout_i;
        mpu_read_gnt_o      = 0;
        mpu_write_gnt_o     = 0;
        mpu_v_src_data_o    = 0;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        VPU, MPU
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = bram_a_dout_i;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o    = bram_b_dout_i;
        // MA
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        VPU, MA
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = bram_a_dout_i;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_b_dout_i;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        VPU, ROUTER
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = bram_a_dout_i;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        ma_read_gnt_o     = 0;
        ma_write_gnt_o    = 0;
        ma_v_src_data_o   = 0;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_b_dout_i;
      end
      {
        MPU, NONE
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o    = bram_a_dout_i;
        // MA
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MPU, VPU
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = bram_b_dout_i;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o    = bram_a_dout_i;
        // MA
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MPU, MA
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o = bram_a_dout_i;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_b_dout_i;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MPU, ROUTER
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o = bram_a_dout_i;
        // MA
        ma_read_gnt_o    = 0;
        ma_write_gnt_o   = 0;
        ma_v_src_data_o  = 0;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_b_dout_i;
      end
      {
        MA, NONE
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_a_dout_i;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MA, VPU
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = bram_b_dout_i;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_a_dout_i;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MA, MPU
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o = bram_b_dout_i;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o     = bram_a_dout_i;
        // Router
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
      {
        MA, ROUTER
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        if (ma_read_req_i) begin
          ma_read_gnt_o  = 1;
          ma_write_gnt_o = 0;
        end else if (ma_write_req_i) begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 1;
        end else begin
          ma_read_gnt_o  = 0;
          ma_write_gnt_o = 0;
        end
        ma_v_src_data_o = bram_a_dout_i;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_b_dout_i;
      end
      {
        ROUTER, NONE
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        ma_read_gnt_o     = 0;
        ma_write_gnt_o    = 0;
        ma_v_src_data_o   = 0;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_a_dout_i;
      end
      {
        ROUTER, VPU
      } : begin
        // VPU
        if (vpu_read_req_i) begin
          vpu_read_gnt_o  = 1;
          vpu_write_gnt_o = 0;
        end else if (vpu_write_req_i) begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 1;
        end else begin
          vpu_read_gnt_o  = 0;
          vpu_write_gnt_o = 0;
        end
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = bram_b_dout_i;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        ma_read_gnt_o     = 0;
        ma_write_gnt_o    = 0;
        ma_v_src_data_o   = 0;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_a_dout_i;
      end
      {
        ROUTER, MPU
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        if (mpu_read_req_i) begin
          mpu_read_gnt_o  = 1;
          mpu_write_gnt_o = 0;
        end else if (mpu_write_req_i) begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 1;
        end else begin
          mpu_read_gnt_o  = 0;
          mpu_write_gnt_o = 0;
        end
        mpu_v_src_data_o = bram_b_dout_i;
        // MA
        ma_read_gnt_o    = 0;
        ma_write_gnt_o   = 0;
        ma_v_src_data_o  = 0;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_a_dout_i;
      end
      {
        ROUTER, MA
      } : begin
        // VPU
        vpu_read_gnt_o    = 0;
        vpu_write_gnt_o   = 0;
        vpu_v_src1_data_o = 0;
        vpu_v_src2_data_o = 0;
        // MPU
        mpu_read_gnt_o    = 0;
        mpu_write_gnt_o   = 0;
        mpu_v_src_data_o  = 0;
        // MA
        ma_read_gnt_o     = 0;
        ma_write_gnt_o    = 0;
        ma_v_src_data_o   = bram_b_dout_i;
        // Router
        if (router_read_req_i) begin
          router_read_gnt_o  = 1;
          router_write_gnt_o = 0;
        end else if (router_write_req_i) begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 1;
        end else begin
          router_read_gnt_o  = 0;
          router_write_gnt_o = 0;
        end
        router_v_src_data_o = bram_a_dout_i;
      end
      default: begin
        vpu_read_gnt_o      = 0;
        vpu_write_gnt_o     = 0;
        vpu_v_src1_data_o   = 0;
        vpu_v_src2_data_o   = 0;
        mpu_read_gnt_o      = 0;
        mpu_write_gnt_o     = 0;
        mpu_v_src_data_o    = 0;
        ma_read_gnt_o       = 0;
        ma_write_gnt_o      = 0;
        ma_v_src_data_o     = 0;
        router_read_gnt_o   = 0;
        router_write_gnt_o  = 0;
        router_v_src_data_o = 0;
      end
    endcase
  end
endmodule
