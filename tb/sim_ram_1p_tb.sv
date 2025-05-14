`timescale 1ns / 1ps

module sim_ram_1p_tb;

  // Parameters
  localparam DATAWIDTH = 32;
  localparam DEPTH = 16;
  localparam MEMFILE = "tb/init.mem";
  localparam READ_DELAY = 2;
  localparam CLK_PERIOD = 10;

  // Signals
  logic                     clk;
  logic                     en;
  logic                     we;
  logic [$clog2(DEPTH)-1:0] addr;
  logic [    DATAWIDTH-1:0] din;
  logic [    DATAWIDTH-1:0] dout;

  // Instantiate DUT
  ram_1p #(
    .DATAWIDTH (DATAWIDTH),
    .DEPTH     (DEPTH),
    .MEMFILE   (MEMFILE),
    .READ_DELAY(READ_DELAY)
  ) dut (
    .clk (clk),
    .en  (en),
    .we  (we),
    .addr(addr),
    .din (din),
    .dout(dout)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Test stimulus
  initial begin
    // Initialize signals
    en   = 0;
    we   = 0;
    addr = 0;
    din  = 0;

    // Reset and wait
    repeat (5) @(posedge clk);
    $display("Starting test...");

    // Test 1: Write and read
    $display("Test 1: Write and read");
    en   = 1;
    we   = 1;
    addr = 0;
    din  = 32'hDEADBEEF;
    @(posedge clk);
    we = 0;
    repeat (READ_DELAY) @(posedge clk);
    #1ps;  // Delay to capture dout after NBA updates
    if (dout == 32'hDEADBEEF) $display("Read correct: %h", dout);
    else $error("Read failed: expected %h, got %h", 32'hDEADBEEF, dout);

    // Test 2: Random writes and reads
    $display("Test 2: Random writes and reads");
    repeat (10) begin
      en   = 1;
      we   = $random % 2;
      addr = $urandom_range(0, DEPTH - 1);
      din  = $urandom;
      @(posedge clk);
    end
    repeat (READ_DELAY) @(posedge clk);
    #1ps;  // Delay to ensure final read captures post-NBA values

    // Test 3: Check memory initialization
    $display("Test 3: Check memory initialization");
    en   = 1;
    we   = 0;
    addr = 0;
    repeat (READ_DELAY) @(posedge clk);
    #1ps;  // Delay to capture dout after NBA updates
    $display("Init data at addr 0: %h", dout);

    $display("Test completed");
    $finish;
  end

  // Dump waveform
  initial begin
    $dumpfile("sim_ram_1p_tb.vcd");
    $dumpvars(0, sim_ram_1p_tb);
  end

endmodule
