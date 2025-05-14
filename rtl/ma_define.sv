interface datamover_if #(
  parameter AXI_ADDR_WIDTH   = 36,
  parameter BRAM_ADDR_WIDTH  = 10,
  parameter BYTE_TRANS_WIDTH = 15
);

  // Signals for the datamover interface
  logic start;
  logic [AXI_ADDR_WIDTH-1:0] src_axi_addr;
  logic [BRAM_ADDR_WIDTH-1:0] dst_bram_addr;
  logic [BRAM_ADDR_WIDTH-1:0] src_bram_addr;
  logic [AXI_ADDR_WIDTH-1:0] dst_axi_addr;
  logic [BYTE_TRANS_WIDTH-1:0] byte_to_trans;
  logic done;

  // Master modport (MA Controller side)
  modport master(
    output start,
    output src_axi_addr,
    output dst_bram_addr,
    output src_bram_addr,
    output dst_axi_addr,
    output byte_to_trans,
    input done
  );

  // Slave modport (Datamover side)
  modport slave(
    input start,
    input src_axi_addr,
    input dst_bram_addr,
    input src_bram_addr,
    input dst_axi_addr,
    input byte_to_trans,
    output done
  );

endinterface
