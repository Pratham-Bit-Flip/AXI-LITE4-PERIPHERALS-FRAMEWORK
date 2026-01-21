# AXI4-Lite Peripheral Framework — Design Guide

## Overview

This framework provides a clean, reusable, production-ready **AXI4-Lite slave** with a parameterizable register file. It supports:

- **Single-cycle latency** for reads and writes (no bubbles)
- **Back-to-back transactions** on the same or different addresses
- **Independent channels**: Write address, write data, write response, read address, read data operate autonomously
- **Byte-level masking** via write strobes (`wstrb`)
- **Proper AXI handshakes**: `valid` never combinationally depends on `ready`
- **Address decoding** with configurable base address and register count
- **Response codes**: OKAY for valid addresses, DECERR for unmapped regions

---

## Architecture

### Write Path

1. **Write Address & Write Data channels** arrive on the same or subsequent cycles.
2. Both `awvalid && wvalid && awready && wready` must be true to accept the transaction.
3. Address is decoded combinationally to check if it's within the register space.
4. On handshake:
   - Register at the mapped address is updated with write data
   - Byte strobes (`wstrb`) control which bytes are written
   - Write response flag is asserted
5. Write response channel holds `bvalid` until the master acknowledges with `bready`.
6. **Ready signals** (`awready`, `wready`) go low once a response is pending and remain low until response is consumed.

### Read Path

1. **Read Address channel** receives the address when `arvalid && arready`.
2. Address is decoded combinationally.
3. On handshake:
   - Read data is latched immediately (combinational read)
   - Response code is determined (OKAY or DECERR)
   - `rvalid` is asserted
4. Read data and response hold until the master acknowledges with `rready`.
5. **Ready signal** (`arready`) goes low once a response is pending and remains low until response is consumed.

---

## Key Design Decisions

### 1. Separate Write Pending vs. Read Pending

- Write path has its own `w_resp_pending` flag
- Read path has its own `r_valid_pending` flag
- **Result**: Reads and writes can proceed independently (e.g., a read response can be waiting while a new write is accepted, or vice versa)

### 2. Single-Cycle Combinational Read

- Read data is fetched combinationally from the register file
- Data appears on `rdata` in the same cycle the address is accepted
- `rvalid` then holds the data until consumed
- **Benefit**: No pipelining delays; simple, predictable timing

### 3. Ready Depends on Valid, Not Vice Versa

```verilog
// CORRECT: ready can depend on valid
assign awready = !w_resp_pending || bready;

// WRONG: valid depending on ready creates a combinational loop
// awvalid = <some logic> && awready;  // ← DON'T DO THIS
```

This ensures:
- No combinational feedback loops
- Timing paths are unambiguous
- Synthesis tools can easily meet timing

### 4. Address Decoding Depth

All address checks are **combinational**:
- `addr_valid_w = (reg_addr_w < N_REGS)`
- No registered intermediate stages
- Minimal propagation delay

For designs with many registers:
- If timing becomes tight, implement a registered pipeline stage
- Insert a flop between address acceptance and register update
- Trade off latency for timing margin (still single-cycle to the user)

### 5. Byte Strobes (Write Masking)

Each byte of the 32-bit word can be independently masked:
```verilog
if (wstrb[0]) regs[addr][7:0]   <= wdata[7:0];
if (wstrb[1]) regs[addr][15:8]  <= wdata[15:8];
if (wstrb[2]) regs[addr][23:16] <= wdata[23:16];
if (wstrb[3]) regs[addr][31:24] <= wdata[31:24];
```

---

## Parameters

| Parameter      | Default        | Description                          |
|----------------|----------------|--------------------------------------|
| `N_REGS`       | 8              | Number of 32-bit registers           |
| `BASE_ADDR`    | 32'h4000_0000  | Base address of this peripheral      |
| `ADDR_WIDTH`   | 14             | Address width (bits); typically log2(N_REGS*4) + alignment |
| `DATA_WIDTH`   | 32             | Data width (AXI-Lite typically 32)   |

---

## Back-to-Back Transfer Support

### Write-to-Write Back-to-Back

```
Cycle 0:  awvalid, wvalid (first write)
Cycle 1:  bvalid asserted, but...
          awvalid, wvalid (second write) also asserted
          → awready, wready must be driven high (since bready could be high)
          → Second transaction accepted immediately
Cycle 2:  bvalid (for second write)
```

**How the design achieves this:**
```verilog
assign awready = !w_resp_pending || bready;
```
- When a response is pending but `bready` is asserted, `awready` is immediately high
- New write address/data can be accepted the same cycle the response is consumed

### Read-to-Read Back-to-Back

```
Cycle 0:  arvalid (first read)
Cycle 1:  rvalid asserted, and...
          arvalid (second read) also asserted
          → arready must be driven high (if rready is high)
          → Second address accepted immediately
Cycle 2:  rvalid (for second read)
```

**How the design achieves this:**
```verilog
assign arready = !r_valid_pending || rready;
```
- When read response is pending but `rready` is asserted, `arready` is immediately high
- New read address can be accepted the same cycle the previous response is consumed

### No Bubbles

A "bubble" is an idle cycle when the master is ready to send data but the slave is not ready to accept.

**This design eliminates bubbles by:**
1. Keeping `ready` signals high whenever possible
2. Decoupling read and write paths (independent pending flags)
3. Immediately sampling new transactions during response handshakes

---

## Synthesis and Timing

### Timing Path Breakdown

For a 100 MHz clock (10 ns period):

| Path                          | Combinational Delay | Margin |
|-------------------------------|---------------------|--------|
| Address decode (is valid?)    | ~0.5 ns             | 9.5 ns |
| Read data mux                 | ~0.8 ns             | 9.2 ns |
| Response code decode          | ~0.3 ns             | 9.7 ns |
| Register update (wdata, wstrb)| ~0.6 ns             | 9.4 ns |
| Ready signal logic            | ~0.2 ns             | 9.8 ns |

**Typical results:**
- All paths easily meet 100 MHz
- Register count can reach 64+ before needing pipelined reads
- Very conservative margin for modern nodes (28 nm and below)

### Timing Verification Checklist

1. **All `assign` statements are combinational**: ✓ (no blocking assignments)
2. **No latches**: ✓ (all `always @(posedge clk)` have explicit else or default)
3. **No combinational loops**: ✓ (`ready` depends on `valid`, not vice versa)
4. **Address decode is shallow**: ✓ (single comparison, no cascaded logic)

---

## Scalability Considerations

### When Does Single-Cycle Break?

1. **Address decode timing**: If address comparison becomes very deep (e.g., 1000+ registers), insert a pipeline stage:
   ```verilog
   reg addr_valid_r;
   always @(posedge clk) addr_valid_r <= (reg_addr_w < N_REGS);
   ```
   This adds 1 cycle of latency but dramatically improves timing.

2. **Register mux delay**: For deeply nested multiplexers (64+ registers), timing may tighten. Solution:
   - Implement hierarchical read muxes
   - Or add pipeline stage (trade latency for timing margin)

3. **Byte strobe logic**: At 4 independent writes, still negligible. No scaling issues expected.

### Recommended Register Counts (100 MHz, Xilinx 7-Series)

| Register Count | Timing Margin | Pipelining Needed? |
|----------------|---------------|--------------------|
| 8 - 16         | Excellent     | No                 |
| 16 - 32        | Good          | No                 |
| 32 - 64        | Fair          | No (likely okay)   |
| 64 - 128       | Tight         | Yes (recommended)  |
| 128+           | Risky         | Yes (required)     |

---

## Testing and Verification

The testbench (`axil_reg_if_tb.v`) includes 18 comprehensive test cases covering:
- Single and back-to-back reads/writes
- Byte strobes and partial writes
- Unmapped address handling (DECERR)
- Rapid write-read patterns

Run tests: `make sim` (see VERIFICATION_GUIDE.md for details)

---

## Troubleshooting

- **Data incorrect after write**: Check `wstrb` signals and word alignment
- **No responses**: Verify `bready`/`rready` signals from master
- **Timing issues**: Add pipeline stage for >64 registers
- **Synthesis warnings**: Ensure complete if/else coverage in always blocks

---

*For detailed verification procedures, see VERIFICATION_GUIDE.md*

