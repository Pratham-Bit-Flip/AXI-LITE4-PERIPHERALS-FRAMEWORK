`timescale 1ns / 1ps

module axil_reg_if_tb ();

    parameter N_REGS     = 8;
    parameter BASE_ADDR  = 32'h4000_0000;
    parameter ADDR_WIDTH = 14;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    reg                          clk;
    reg                          rst;
    reg                          awvalid;
    wire                         awready;
    reg [31:0]                   awaddr;
    
    // AXI4-Lite Write Data Channel
    reg                          wvalid;
    wire                         wready;
    reg [DATA_WIDTH-1:0]         wdata;
    reg [3:0]                    wstrb;
    
    // AXI4-Lite Write Response Channel
    wire                         bvalid;
    reg                          bready;
    wire [1:0]                   bresp;
    
    // AXI4-Lite Read Address Channel
    reg                          arvalid;
    wire                         arready;
    reg [31:0]                   araddr;
    
    // AXI4-Lite Read Data Channel
    wire                         rvalid;
    reg                          rready;
    wire [DATA_WIDTH-1:0]        rdata;
    wire [1:0]                   rresp;
    
    // Register file interface
    wire [N_REGS*32-1:0]         regs_out;
    
    // Test variables
    integer                      pass_count = 0;
    integer                      fail_count = 0;
    reg [31:0]                   read_data;
    reg [1:0]                    read_resp;
    
    // Instantiate DUT
    
    axil_reg_if #(
        .N_REGS(N_REGS),
        .BASE_ADDR(BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .awvalid    (awvalid),
        .awready    (awready),
        .awaddr     (awaddr),
        .wvalid     (wvalid),
        .wready     (wready),
        .wdata      (wdata),
        .wstrb      (wstrb),
        .bvalid     (bvalid),
        .bready     (bready),
        .bresp      (bresp),
        .arvalid    (arvalid),
        .arready    (arready),
        .araddr     (araddr),
        .rvalid     (rvalid),
        .rready     (rready),
        .rdata      (rdata),
        .rresp      (rresp),
        .regs_out   (regs_out),
        .regs_in    ()
    );
    
    // Clock Generation
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // AXI Write Task
    
    /*
     * Write a 32-bit value to a register address
     * Handles full AXI write sequence (address -> data -> response)
     */
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            // Wait for ready
            @(posedge clk);
            while (~awready || ~wready) @(posedge clk);
            
            // Drive write address and data
            awvalid = 1'b1;
            awaddr  = addr;
            wvalid  = 1'b1;
            wdata   = data;
            wstrb   = strb;
            bready  = 1'b0;
            
            @(posedge clk);
            awvalid = 1'b0;
            wvalid  = 1'b0;
            
            // Wait for write response
            while (~bvalid) @(posedge clk);
            
            bready = 1'b1;
            @(posedge clk);
            bready = 1'b0;
        end
    endtask
    
    // AXI Read Task
    
    /*
     * Read a 32-bit value from a register address
     * Handles full AXI read sequence (address -> data)
     */
    task axi_read;
        input  [31:0] addr;
        output [31:0] data;
        output [1:0]  resp;
        begin
            // Wait for ready
            @(posedge clk);
            while (~arready) @(posedge clk);
            
            // Drive read address
            arvalid = 1'b1;
            araddr  = addr;
            rready  = 1'b0;
            
            @(posedge clk);
            arvalid = 1'b0;
            
            // Wait for read response
            while (~rvalid) @(posedge clk);
            
            rready = 1'b1;
            data   = rdata;
            resp   = rresp;
            @(posedge clk);
            rready = 1'b0;
        end
    endtask
    
    // Comparison Task
    
    task check;
        input [31:0] expected;
        input [31:0] actual;
        input [255:0] label;
        begin
            if (expected === actual) begin
                $display("[PASS] %s: expected=0x%08h, actual=0x%08h", label, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s: expected=0x%08h, actual=0x%08h", label, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Main Testbench
    
    initial begin
        // Initialize
        clk     = 1'b0;
        rst     = 1'b1;
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        arvalid = 1'b0;
        rready  = 1'b0;
        
        // Reset
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        
        $display("\n========================================");
        $display("  AXI4-Lite Register Interface Testbench");
        $display("========================================\n");
        
        // Test 1: Single Write and Read
        $display("\n[TEST 1] Single Write and Read");
        $display("  Writing 0xDEADBEEF to address 0x%08h (reg[0])", BASE_ADDR);
        axi_write(BASE_ADDR + 32'h0000, 32'hDEADBEEF, 4'b1111);
        
        $display("  Reading from address 0x%08h (reg[0])", BASE_ADDR);
        axi_read(BASE_ADDR + 32'h0000, read_data, read_resp);
        check(32'hDEADBEEF, read_data, "Single write/read");
        check(2'b00, read_resp, "Response code (OKAY)");
        
        // Test 2: Back-to-Back Writes
        $display("\n[TEST 2] Back-to-Back Writes");
        repeat (2) @(posedge clk);
        
        axi_write(BASE_ADDR + 32'h0000, 32'h11111111, 4'b1111);
        axi_write(BASE_ADDR + 32'h0004, 32'h22222222, 4'b1111);
        axi_write(BASE_ADDR + 32'h0008, 32'h33333333, 4'b1111);
        axi_write(BASE_ADDR + 32'h000C, 32'h44444444, 4'b1111);
        
        $display("  Reading back all written registers");
        repeat (2) @(posedge clk);
        
        axi_read(BASE_ADDR + 32'h0000, read_data, read_resp);
        check(32'h11111111, read_data, "Read reg[0]");
        
        axi_read(BASE_ADDR + 32'h0004, read_data, read_resp);
        check(32'h22222222, read_data, "Read reg[1]");
        
        axi_read(BASE_ADDR + 32'h0008, read_data, read_resp);
        check(32'h33333333, read_data, "Read reg[2]");
        
        axi_read(BASE_ADDR + 32'h000C, read_data, read_resp);
        check(32'h44444444, read_data, "Read reg[3]");
        
        // Test 3: Back-to-Back Reads
        $display("\n[TEST 3] Back-to-Back Reads");
        repeat (2) @(posedge clk);
        
        axi_read(BASE_ADDR + 32'h0000, read_data, read_resp);
        check(32'h11111111, read_data, "Back-to-back read reg[0]");
        
        axi_read(BASE_ADDR + 32'h0004, read_data, read_resp);
        check(32'h22222222, read_data, "Back-to-back read reg[1]");
        
        axi_read(BASE_ADDR + 32'h0008, read_data, read_resp);
        check(32'h33333333, read_data, "Back-to-back read reg[2]");
        
        // Test 4: Partial Writes with Byte Strobes
        $display("\n[TEST 4] Partial Writes with Byte Strobes");
        repeat (2) @(posedge clk);
        
        $display("  Writing 0x12345678 to reg[4] with all strobes");
        axi_write(BASE_ADDR + 32'h0010, 32'h12345678, 4'b1111);
        axi_read(BASE_ADDR + 32'h0010, read_data, read_resp);
        check(32'h12345678, read_data, "Full write");
        
        $display("  Updating low byte to 0xAA with strobe[0] only");
        axi_write(BASE_ADDR + 32'h0010, 32'hDEADBEAA, 4'b0001);
        axi_read(BASE_ADDR + 32'h0010, read_data, read_resp);
        check(32'h123456AA, read_data, "Partial write (byte 0)");
        
        $display("  Updating high byte to 0xCC with strobe[3] only");
        axi_write(BASE_ADDR + 32'h0010, 32'hCCADCEEF, 4'b1000);
        axi_read(BASE_ADDR + 32'h0010, read_data, read_resp);
        check(32'hCC3456AA, read_data, "Partial write (byte 3)");
        
        // Test 5: Unmapped Address (DECERR)
        $display("\n[TEST 5] Unmapped Address Access");
        repeat (2) @(posedge clk);
        
        $display("  Writing to unmapped address (reg[15] > N_REGS-1)");
        axi_write(BASE_ADDR + 32'h003C, 32'hFFFFFFFF, 4'b1111);
        
        $display("  Reading from unmapped address");
        axi_read(BASE_ADDR + 32'h003C, read_data, read_resp);
        check(2'b11, read_resp, "Response code (DECERR for unmapped)");
        
        // Test 6: Rapid Write-Read Pattern
        $display("\n[TEST 6] Rapid Write-Read Pattern (No Bubbles)");
        repeat (2) @(posedge clk);
        
        fork
            begin
                // Write sequence
                axi_write(BASE_ADDR + 32'h0000, 32'hAAAAAAAA, 4'b1111);
                axi_write(BASE_ADDR + 32'h0004, 32'hBBBBBBBB, 4'b1111);
                axi_write(BASE_ADDR + 32'h0008, 32'hCCCCCCCC, 4'b1111);
            end
            begin
                // Read sequence (with slight offset to allow writes first)
                repeat (5) @(posedge clk);
                axi_read(BASE_ADDR + 32'h0000, read_data, read_resp);
                check(32'hAAAAAAAA, read_data, "Read after rapid writes");
            end
        join
        
        // Test Summary
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("  PASS: %0d", pass_count);
        $display("  FAIL: %0d", fail_count);
        $display("========================================\n");
        
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  TESTS FAILED!");
        end
        
        repeat (5) @(posedge clk);
        $finish;
    end
    
    // Waveform Dump (optional)
    
    initial begin
        $dumpfile("axi_reg_if.vcd");
        $dumpvars(0, axil_reg_if_tb);
    end
    
endmodule
