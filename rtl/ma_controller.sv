`timescale 1ns / 1ps

module ma_controller (
  input clk,
  input rst_n,

  // Calibration 
  input      [3:0] ma_ddr4_calib_complete_i,
  output reg       ma_ddr4_linkup,

  // Control interface
  input        ma_start,
  input        ma_select_v_m,
  input        ma_v_load_or_store,
  input [ 9:0] ma_v_m_reg,
  input [ 4:0] ma_a_reg,
  input [63:0] ma_a_offset,

  // Address register file interface
  output reg        arf_en,
  output reg        arf_we,
  output reg [ 4:0] arf_addr,
  input      [63:0] arf_dout,

  // MRF interface
  output reg        mrf_start,
  output reg        mrf_en,
  output reg [35:0] mrf_src_axi_addr,
  output reg [ 5:0] mrf_dst_bram_addr,
  output reg [14:0] mrf_byte_to_transfer,
  input             mrf_done,

  //VRF AXI2BRAM interface
  output reg        vrf_ldr_start,
  output reg [35:0] vrf_ldr_src_axi_addr,
  output reg [ 9:0] vrf_ldr_dst_bram_addr,
  output reg [14:0] vrf_ldr_byte_to_transfer,
  input             vrf_ldr_done,
  
  //VRF BRAM2AXI interface
  output reg        vrf_store_start,
  output reg [ 9:0] vrf_store_src_bram_addr,
  output reg [35:0] vrf_store_dst_axi_addr,
  output reg [14:0] vrf_store_byte_to_transfer,
  input             vrf_store_done,
  


  output reg ma_done
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

  reg [63:0] base_addr;
  reg [63:0] effective_addr;

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
      IDLE:           if (ma_start) next_state = READ_ARF;
      READ_ARF:       next_state = WAIT_ARF;
      WAIT_ARF:       next_state = WAIT_ARF2;
      WAIT_ARF2:      next_state = CALC_ADDR;
      CALC_ADDR:      next_state = START_TRANSFER;
      START_TRANSFER: next_state = WAIT_DONE;
      WAIT_DONE:      if (mrf_done) next_state = IDLE;
    endcase
  end

  // Output and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ma_ddr4_linkup          <= 0;
      arf_en               <= 0;
      arf_we               <= 0;
      arf_addr             <= 0;
      ma_done              <= 0;
      effective_addr       <= 0;
      base_addr            <= 0;
      mrf_start            <= 0;
      mrf_en               <= 0;
      mrf_src_axi_addr     <= 36'd0;
      mrf_dst_bram_addr    <= 6'd0;
      mrf_byte_to_transfer <= 15'd0;

      vrf_ldr_start <= 0;
      vrf_ldr_src_axi_addr <= 36'd0;
      vrf_ldr_dst_bram_addr <= 9'd0;
      vrf_ldr_byte_to_transfer <= 15'd0;

      vrf_store_start <= 0;
      vrf_store_src_bram_addr <= 9'd0;
      vrf_store_dst_axi_addr <= 36'd0;
      vrf_store_byte_to_transfer <= 15'd0;
    end else begin
      case (state)
        WAIT_CALIB: begin
          ma_ddr4_linkup <= &ma_ddr4_calib_complete_i;
          ma_done     <= 0;
        end

        IDLE: begin
          arf_en    <= 0;
          ma_done   <= 0;
          mrf_start <= 0;
          mrf_en    <= 0;
        end

        READ_ARF: begin
          arf_en   <= 1;
          arf_we   <= 0;
          arf_addr <= ma_a_reg;
        end

        WAIT_ARF: begin
          arf_en    <= 1;
          base_addr <= arf_dout;
        end

        WAIT_ARF2: begin
          arf_en    <= 0;
          base_addr <= arf_dout;
        end

        CALC_ADDR: begin
          arf_en         <= 0;
          base_addr      <= arf_dout;
          effective_addr <= arf_dout + ma_a_offset;
        end

        START_TRANSFER: begin
            if(ma_select_v_m) begin
                mrf_start            <= 1;
                mrf_en               <= 1;
                mrf_src_axi_addr     <= effective_addr[35:0];
                mrf_dst_bram_addr    <= ma_v_m_reg[5:0];
                mrf_byte_to_transfer <= 15'd2048;
            end else begin
                if(ma_v_load_or_store == 0) begin
                    vrf_ldr_start <= 1;
                    vrf_ldr_src_axi_addr <= effective_addr[35:0];
                    vrf_ldr_dst_bram_addr <= ma_v_m_reg[9:0];
                    vrf_ldr_byte_to_transfer <= 15'd128;
                end else begin
                    vrf_store_start <= 1;
                    vrf_store_dst_axi_addr <= effective_addr[35:0];
                    vrf_store_src_bram_addr <= ma_v_m_reg[9:0];
                    vrf_store_byte_to_transfer <= 15'd128;
                    end
            end
        end

        WAIT_DONE: begin
          mrf_start <= 0;
          mrf_en    <= ~mrf_done;
          vrf_ldr_start <= 0;
          vrf_store_start <= 0;
          if (ma_select_v_m) begin
                ma_done <= &mrf_done;
            end else begin
                if (ma_v_load_or_store == 0)
                    ma_done <= vrf_ldr_done;
                else
                    ma_done <= vrf_store_done;
            end
        end
      endcase
    end
  end

endmodule
