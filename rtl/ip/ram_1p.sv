// Single-port RAM with configurable data width, depth, memory init, and read delay
module ram_1p #(
  parameter DATAWIDTH  = 32,          // Width of data bus
  parameter DEPTH      = 256,         // Number of memory locations
  parameter MEMFILE    = "init.mem",  // Memory initialization file
  parameter READ_DELAY = 1            // Number of cycles for read delay
) (
  // Port signals
  input  logic                     clk,   // Clock
  input  logic                     en,    // Enable
  input  logic                     we,    // Write enable
  input  logic [$clog2(DEPTH)-1:0] addr,  // Address
  input  logic [    DATAWIDTH-1:0] din,   // Data input
  output logic [    DATAWIDTH-1:0] dout   // Data output
);

  // Memory array
  logic [DATAWIDTH-1:0] mem[0:DEPTH-1];

  // Memory initialization (simulation-only)
  initial begin
    if (MEMFILE != "") begin
      $readmemh(MEMFILE, mem);
    end
  end

  // Write logic
  always_ff @(posedge clk) begin
    if (en && we) begin
      mem[addr] <= din;
    end
  end

  // Read logic
  logic [DATAWIDTH-1:0] read_data;
  logic [DATAWIDTH-1:0] delay_line[0:READ_DELAY-1];

  // Asynchronous read from memory
  always_comb begin
    read_data = mem[addr];
  end

  // Read delay pipeline
  always_ff @(posedge clk) begin
    if (en) begin
      delay_line[0] <= read_data;
      for (int i = 1; i < READ_DELAY; i++) begin
        delay_line[i] <= delay_line[i-1];
      end
    end
  end

  // Output the delayed read data
  assign dout = (READ_DELAY > 0) ? delay_line[READ_DELAY-1] : read_data;

endmodule
