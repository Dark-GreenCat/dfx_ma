`timescale 1ps / 1ps

module sim_ram_2p_tb;

  // Parameters
  localparam DATAWIDTH_A = 32;
  localparam DEPTH_A = 16;
  localparam DATAWIDTH_B = 16;
  localparam DEPTH_B = 32;
  localparam MEMFILE = "tb/init.mem";
  localparam READ_DELAY = 2;
  localparam CLK_PERIOD_A = 10;
  localparam CLK_PERIOD_B = 12;

  // Signals
  logic                       clk_a;
  logic                       en_a;
  logic                       we_a;
  logic [$clog2(DEPTH_A)-1:0] addr_a;
  logic [    DATAWIDTH_A-1:0] din_a;
  logic [    DATAWIDTH_A-1:0] dout_a;

  logic                       clk_b;
  logic                       en_b;
  logic                       we_b;
  logic [$clog2(DEPTH_B)-1:0] addr_b;
  logic [    DATAWIDTH_B-1:0] din_b;
  logic [    DATAWIDTH_B-1:0] dout_b;

  // Instantiate DUT
  ram_2p #(
    .DATAWIDTH_A(DATAWIDTH_A),
    .DEPTH_A    (DEPTH_A),
    .DATAWIDTH_B(DATAWIDTH_B),
    .DEPTH_B    (DEPTH_B),
    .MEMFILE    (MEMFILE),
    .READ_DELAY (READ_DELAY)
  ) dut (
    .clk_a (clk_a),
    .en_a  (en_a),
    .we_a  (we_a),
    .addr_a(addr_a),
    .din_a (din_a),
    .dout_a(dout_a),
    .clk_b (clk_b),
    .en_b  (en_b),
    .we_b  (we_b),
    .addr_b(addr_b),
    .din_b (din_b),
    .dout_b(dout_b)
  );

  // Clock generation
  initial begin
    clk_a = 0;
    forever #(CLK_PERIOD_A / 2) clk_a = ~clk_a;
  end

  initial begin
    clk_b = 0;
    forever #(CLK_PERIOD_B / 2) clk_b = ~clk_b;
  end

  // Shifted clock for Port A sampling
  logic sclk_a;
  initial begin
    #1;
    sclk_a = 0;
    forever #(CLK_PERIOD_A / 2) sclk_a = ~sclk_a;
  end

  // Shifted clock for Port B sampling
  logic sclk_b;
  initial begin
    #1;
    sclk_b = 0;
    forever #(CLK_PERIOD_B / 2) sclk_b = ~sclk_b;
  end

  // Test stimulus
  initial begin
    // Initialize signals
    en_a   = 0;
    we_a   = 0;
    addr_a = 0;
    din_a  = 0;
    en_b   = 0;
    we_b   = 0;
    addr_b = 0;
    din_b  = 0;

    // Reset and wait
    repeat (5) @(posedge clk_a);
    $display("Starting test...");

    // Test 1: Write and read on Port A
    @(posedge clk_a);
    $display("Test 1: Write and read on Port A");
    en_a   = 1;
    we_a   = 1;
    addr_a = 0;
    din_a  = 32'hDEADBEEF;
    @(posedge clk_a);
    we_a = 0;
    repeat (READ_DELAY) @(posedge clk_a);
    @(posedge sclk_a);
    if (dout_a == 32'hDEADBEEF) $display("Port A read correct: %h", dout_a);
    else $display("Port A read failed: expected %h, got %h", 32'hDEADBEEF, dout_a);

    // Test 2: Write and read on Port B
    @(posedge clk_b);
    $display("Test 2: Write and read on Port B");
    en_b   = 1;
    we_b   = 1;
    addr_b = 0;
    din_b  = 16'hCAFE;  // Adjusted for DATAWIDTH_B=16
    @(posedge clk_b);
    we_b = 0;
    repeat (READ_DELAY) @(posedge clk_b);
    @(posedge sclk_b);
    if (dout_b == 16'hCAFE) $display("Port B read correct: %h", dout_b);
    else $display("Port B read failed: expected %h, got %h", 16'hCAFE, dout_b);

    // Test 3: Random writes and reads
    @(posedge clk_a);
    @(posedge clk_b);
    $display("Test 3: Random writes and reads");
    repeat (10) begin
      en_a   = 1;
      we_a   = $random % 2;
      addr_a = $urandom_range(0, DEPTH_A - 1);
      din_a  = $urandom;
      en_b   = 1;
      we_b   = $random % 2;
      addr_b = $urandom_range(0, DEPTH_B - 1);
      din_b  = $urandom;
      @(posedge clk_a);
      @(posedge clk_b);
    end
    repeat (READ_DELAY) @(posedge clk_a);
    repeat (READ_DELAY) @(posedge clk_b);

    // Test 4: Check memory initialization
    @(posedge clk_a);
    @(posedge clk_b);
    $display("Test 4: Check memory initialization");
    en_a   = 1;
    we_a   = 0;
    addr_a = 0;
    en_b   = 1;
    we_b   = 0;
    addr_b = 0;
    repeat (READ_DELAY) @(posedge clk_a);
    repeat (READ_DELAY) @(posedge clk_b);
    @(posedge sclk_a);
    $display("Port A init data at addr 0: %h", dout_a);
    @(posedge sclk_b);
    $display("Port B init data at addr 0: %h", dout_b);

    $display("Test completed");
    $finish;
  end

  // Dump waveform
  initial begin
    $dumpfile("sim_ram_2p_tb.vcd");
    $dumpvars(0, sim_ram_2p_tb);
  end

endmodule
