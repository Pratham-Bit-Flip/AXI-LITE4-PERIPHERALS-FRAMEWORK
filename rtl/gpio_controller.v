module gpio_controller #(
    parameter BASE_ADDR = 32'h4000_0000,
    parameter GPIO_WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   rst,
    
    // AXI4-Lite Slave Interface
    input  wire                   awvalid,
    output wire                   awready,
    input  wire [31:0]            awaddr,
    input  wire                   wvalid,
    output wire                   wready,
    input  wire [31:0]            wdata,
    input  wire [3:0]             wstrb,
    output wire                   bvalid,
    input  wire                   bready,
    output wire [1:0]             bresp,
    
    input  wire                   arvalid,
    output wire                   arready,
    input  wire [31:0]            araddr,
    output wire                   rvalid,
    input  wire                   rready,
    output wire [31:0]            rdata,
    output wire [1:0]             rresp,
    
    // GPIO Interface
    output wire [GPIO_WIDTH-1:0]  gpio_out,        // Output driver
    output wire [GPIO_WIDTH-1:0]  gpio_out_en,     // Output enable (1=drive, 0=high-Z)
    input  wire [GPIO_WIDTH-1:0]  gpio_in,         // Input pins
    output wire                   gpio_interrupt
);

    wire [127:0]  regs_out;
    wire [127:0]  regs_in;

    // Register map: [0]=output, [1]=input(RO), [2]=direction, [3]=int_mask
    wire [31:0] gpio_data_out   = regs_out[31:0];
    wire [31:0] gpio_data_in    = regs_out[63:32];
    wire [31:0] gpio_direction  = regs_out[95:64];
    wire [31:0] gpio_int_mask   = regs_out[127:96];
    
    axil_reg_if #(
        .N_REGS(4),
        .BASE_ADDR(BASE_ADDR),
        .ADDR_WIDTH(14),
        .DATA_WIDTH(32)
    ) axil_slave (
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
        .regs_in    (regs_in)
    );

    // Output enable: 1=drive output, 0=high-Z (input mode)
    assign gpio_out_en = gpio_direction[GPIO_WIDTH-1:0];
    assign gpio_out    = gpio_data_out[GPIO_WIDTH-1:0];

    reg  [GPIO_WIDTH-1:0]  gpio_in_prev;
    wire [GPIO_WIDTH-1:0]  gpio_in_changed;

    assign gpio_in_changed = gpio_in ^ gpio_in_prev;
    
    always @(posedge clk) begin
        if (rst) begin
            gpio_in_prev <= {GPIO_WIDTH{1'b0}};
        end else begin
            gpio_in_prev <= gpio_in;
        end
    end

    // Interrupt on any masked pin change
    assign gpio_interrupt = |(gpio_in_changed & gpio_int_mask[GPIO_WIDTH-1:0]);

    // Feed input pin state back to register file for AXI reads
    assign regs_in = {
        gpio_int_mask,
        gpio_direction,
        gpio_in[31:0],      // Input register reflects actual pin state
        gpio_data_out
    };
    
endmodule
