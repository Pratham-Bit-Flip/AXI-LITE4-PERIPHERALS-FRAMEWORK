module axil_reg_if #(
    parameter N_REGS      = 8,
    parameter BASE_ADDR   = 32'h4000_0000,
    parameter ADDR_WIDTH  = 14,
    parameter DATA_WIDTH  = 32
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    awvalid,
    output wire                    awready,
    input  wire [31:0]             awaddr,
    input  wire                    wvalid,
    output wire                    wready,
    input  wire [DATA_WIDTH-1:0]   wdata,
    input  wire [3:0]              wstrb,
    output wire                    bvalid,
    input  wire                    bready,
    output wire [1:0]              bresp,
    input  wire                    arvalid,
    output wire                    arready,
    input  wire [31:0]             araddr,
    output wire                    rvalid,
    input  wire                    rready,
    output wire [DATA_WIDTH-1:0]   rdata,
    output wire [1:0]              rresp,
    output wire [N_REGS*32-1:0]    regs_out,
    input  wire [N_REGS*32-1:0]    regs_in
);

    localparam ADDR_LSB = 2;  // Byte addressing within 32-bit word
    localparam REG_DEPTH = N_REGS;
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_EXOKAY = 2'b01;
    localparam RESP_DECERR = 2'b11;

    reg [31:0] regs [REG_DEPTH-1:0];

    wire addr_valid_w;
    wire addr_valid_r;
    wire [ADDR_WIDTH-3:0] reg_addr_w;  // Word-aligned address
    wire [ADDR_WIDTH-3:0] reg_addr_r;
    wire addr_in_range_w;
    wire addr_in_range_r;
    
    assign reg_addr_w     = awaddr[ADDR_WIDTH-1:ADDR_LSB];
    assign addr_in_range_w = (reg_addr_w < N_REGS);
    assign addr_valid_w   = addr_in_range_w;
    
    assign reg_addr_r     = araddr[ADDR_WIDTH-1:ADDR_LSB];
    assign addr_in_range_r = (reg_addr_r < N_REGS);
    assign addr_valid_r   = addr_in_range_r;

    reg                  w_addr_en;
    reg                  w_resp_pending;
    reg [ADDR_WIDTH-3:0] w_addr;
    reg [1:0]            w_resp_code;

    // Write happens when both address and data are valid
    wire w_addr_hs = awvalid && wvalid && (!w_resp_pending || bready);

// Ready when no pending response or master consuming response
    assign awready = !w_resp_pending || bready;
    assign wready  = !w_resp_pending || bready;
    wire [1:0] w_resp_code_next = addr_valid_w ? RESP_OKAY : RESP_DECERR;
    assign bvalid = w_resp_pending;
    assign bresp  = w_resp_code;
    always @(posedge clk) begin
        if (rst) begin
            w_resp_pending <= 1'b0;
            w_addr         <= {(ADDR_WIDTH-ADDR_LSB){1'b0}};
            w_resp_code    <= RESP_OKAY;
        end else begin
            if (w_resp_pending && bready) begin
                w_resp_pending <= 1'b0;
            end else if (w_addr_hs) begin
                w_resp_pending <= 1'b1;
                w_addr         <= reg_addr_w;
                w_resp_code    <= w_resp_code_next;
            end
        end
    end
    
    integer reg_init_idx;

    always @(posedge clk) begin
        if (rst) begin
            for (reg_init_idx = 0; reg_init_idx < REG_DEPTH; reg_init_idx = reg_init_idx + 1)
                regs[reg_init_idx] <= 32'h0000_0000;
        end else begin
            if (w_addr_hs && addr_valid_w) begin
                // Apply byte strobes for selective byte updates
                if (wstrb[0]) regs[reg_addr_w][7:0]   <= wdata[7:0];
                if (wstrb[1]) regs[reg_addr_w][15:8]  <= wdata[15:8];
                if (wstrb[2]) regs[reg_addr_w][23:16] <= wdata[23:16];
                if (wstrb[3]) regs[reg_addr_w][31:24] <= wdata[31:24];
            end
        end
    end

    reg                  r_valid_pending;
    reg [31:0]           r_data_latched;
    reg [1:0]            r_resp_code;

    // Combinational read for single-cycle latency
    wire [31:0] r_data_comb = (addr_valid_r && !rst) ? regs[reg_addr_r] : 32'h0000_0000;
    wire [1:0]  r_resp_comb = addr_valid_r ? RESP_OKAY : RESP_DECERR;
    wire r_addr_hs = arvalid && (!r_valid_pending || rready);
    
    assign arready = !r_valid_pending || rready;
    assign rvalid = r_valid_pending;
    assign rdata  = r_data_latched;
    assign rresp  = r_resp_code;

    always @(posedge clk) begin
        if (rst) begin
            r_valid_pending <= 1'b0;
            r_data_latched  <= 32'h0000_0000;
            r_resp_code     <= RESP_OKAY;
        end else begin
            if (r_valid_pending && rready) begin
                r_valid_pending <= 1'b0;
            end else if (r_addr_hs) begin
                r_valid_pending <= 1'b1;
                r_data_latched  <= r_data_comb;
                r_resp_code     <= r_resp_comb;
            end
        end
    end
    
    // Concatenate all registers for external access
    genvar i;
    generate
        for (i = 0; i < REG_DEPTH; i = i + 1) begin : gen_regs_out
            assign regs_out[(i+1)*32-1:i*32] = regs[i];
        end
    endgenerate

endmodule
