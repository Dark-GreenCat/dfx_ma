// Dual-port RAM with separate data width and depth per port, same total capacity
module ram_2p #(
    parameter DATAWIDTH_A = 32,            // Width of data bus for Port A
    parameter DEPTH_A = 16,               // Number of memory locations for Port A
    parameter DATAWIDTH_B = 16,            // Width of data bus for Port B
    parameter DEPTH_B = 32,               // Number of memory locations for Port B
    parameter MEMFILE = "init.mem",       // Memory initialization file
    parameter READ_DELAY = 2,              // Number of cycles for read delay
    parameter TOTAL_BITS = DATAWIDTH_A * DEPTH_A  // Total memory capacity in bits
) (
    // Port A signals
    input  logic                  clk_a,    // Port A clock
    input  logic                  en_a,     // Port A enable
    input  logic                  we_a,     // Port A write enable
    input  logic [$clog2(DEPTH_A)-1:0] addr_a, // Port A address
    input  logic [DATAWIDTH_A-1:0] din_a,   // Port A data input
    output logic [DATAWIDTH_A-1:0] dout_a,  // Port A data output

    // Port B signals
    input  logic                  clk_b,    // Port B clock
    input  logic                  en_b,     // Port B enable
    input  logic                  we_b,     // Port B write enable
    input  logic [$clog2(DEPTH_B)-1:0] addr_b, // Port B address
    input  logic [DATAWIDTH_B-1:0] din_b,   // Port B data input
    output logic [DATAWIDTH_B-1:0] dout_b   // Port B data output
);

    // Check total memory capacity at elaboration
    initial begin
        assert (DATAWIDTH_A * DEPTH_A == DATAWIDTH_B * DEPTH_B)
        else $fatal("Error: DATAWIDTH_A * DEPTH_A (%0d) must equal DATAWIDTH_B * DEPTH_B (%0d)", 
                    DATAWIDTH_A * DEPTH_A, DATAWIDTH_B * DEPTH_B);
    end

    // Memory array (word-level for synthesis compatibility)
    logic [DATAWIDTH_A-1:0] mem [0:DEPTH_A-1];

    // Memory initialization (simulation-only, using a temporary array)
    initial begin
        if (MEMFILE != "") begin
            $readmemh(MEMFILE, mem);
        end
    end

    // Address mapping functions
    function automatic logic [$clog2(DEPTH_A)-1:0] addr_a_to_index(input logic [$clog2(DEPTH_A)-1:0] addr);
        return addr;
    endfunction

    function automatic logic [$clog2(DEPTH_A)-1:0] addr_b_to_index(input logic [$clog2(DEPTH_B)-1:0] addr);
        // Map Port B address to Port A address space
        return (addr * DATAWIDTH_B) / DATAWIDTH_A;
    endfunction

    // Bit offset for Port B writes (lower or upper DATAWIDTH_B bits)
    function automatic logic [$clog2(DATAWIDTH_A)-1:0] addr_b_bit_offset(input logic [$clog2(DEPTH_B)-1:0] addr);
        // Returns 0 for lower DATAWIDTH_B bits, DATAWIDTH_B for upper
        return (addr[0]) ? DATAWIDTH_B : 0;
    endfunction

    // Single write logic for both ports (arbitrated, clk_a domain)
    always_ff @(posedge clk_a) begin
        if (en_a && we_a) begin
            mem[addr_a_to_index(addr_a)] <= din_a;
        end
        if (en_b && we_b) begin
            // Arbitration: Port A has priority
            automatic logic [$clog2(DEPTH_A)-1:0] addr_b_mapped = addr_b_to_index(addr_b);
            if (!(en_a && we_a && addr_a_to_index(addr_a) == addr_b_mapped)) begin
                // Read-modify-write to update only DATAWIDTH_B bits
                automatic logic [DATAWIDTH_A-1:0] current_data = mem[addr_b_mapped];
                automatic logic [$clog2(DATAWIDTH_A)-1:0] bit_offset = addr_b_bit_offset(addr_b);
                current_data[bit_offset +: DATAWIDTH_B] = din_b;
                mem[addr_b_mapped] <= current_data;
            end
        end
    end

    // Port A read logic
    logic [DATAWIDTH_A-1:0] read_data_a;
    logic [DATAWIDTH_A-1:0] delay_line_a [0:READ_DELAY-1];

    // Asynchronous read from memory on Port A
    always_comb begin
        read_data_a = mem[addr_a_to_index(addr_a)];
    end

    // Read delay pipeline for Port A
    always_ff @(posedge clk_a) begin
        if (en_a) begin
            delay_line_a[0] <= read_data_a;
            for (int i = 1; i < READ_DELAY; i++) begin
                delay_line_a[i] <= delay_line_a[i-1];
            end
        end
    end

    // Output the delayed read data for Port A
    assign dout_a = (READ_DELAY > 0) ? delay_line_a[READ_DELAY-1] : read_data_a;

    // Port B read logic
    logic [DATAWIDTH_B-1:0] read_data_b;
    logic [DATAWIDTH_B-1:0] delay_line_b [0:READ_DELAY-1];

    // Asynchronous read from memory on Port B
    always_comb begin
        // Extract DATAWIDTH_B bits from DATAWIDTH_A-sized word
        automatic logic [$clog2(DEPTH_A)-1:0] addr_b_mapped = addr_b_to_index(addr_b);
        automatic logic [$clog2(DATAWIDTH_A)-1:0] bit_offset = addr_b_bit_offset(addr_b);
        read_data_b = mem[addr_b_mapped][bit_offset +: DATAWIDTH_B];
    end

    // Read delay pipeline for Port B
    always_ff @(posedge clk_b) begin
        if (en_b) begin
            delay_line_b[0] <= read_data_b;
            for (int i = 1; i < READ_DELAY; i++) begin
                delay_line_b[i] <= delay_line_b[i-1];
            end
        end
    end

    // Output the delayed read data for Port B
    assign dout_b = (READ_DELAY > 0) ? delay_line_b[READ_DELAY-1] : read_data_b;

endmodule
