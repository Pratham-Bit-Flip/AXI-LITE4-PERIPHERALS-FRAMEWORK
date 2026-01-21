# Complete Verification & Synthesis Guide

A step-by-step guide to verify, simulate, synthesize, and implement your AXI4-Lite IP.

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start-5-minutes)
2. [Using the Makefile](#-using-the-makefile)
3. [Simulation](#-simulation)
4. [Waveform Analysis](#-waveform-analysis)
5. [Synthesis](#-synthesis)
6. [Verification Checklist](#-verification-checklist)

---

## 🚀 Quick Start

```bash
make sim
```

✅ Expected: `ALL TESTS PASSED! (18/18)`

```bash
make wave  # View waveforms (optional)
make clean # Clean up
```

---

## 🛠️ Using the Makefile

| Command | Description |
|---------|-------------|
| `make sim` | Run simulation with iverilog |
| `make sim-verilator` | Run with Verilator (faster) |
| `make wave` | View waveform in GTKWave |
| `make clean` | Remove build artifacts |
| `make help` | Show all targets |

**Output files:**
- `build/tb.vvp` - Compiled simulation
- `build/axi_reg_if.vcd` - Waveform data

---

## 🧪 Simulation

**Using Makefile:**
```bash
make sim
```

**Manual iverilog:**
```bash
iverilog -o build/tb.vvp rtl/axil_reg_if.v rtl/gpio_controller.v tb/axil_reg_if_tb.v
vvp build/tb.vvp
gtkwave build/axi_reg_if.vcd
```

---

## 📊 Waveform Analysis

### Opening Waveforms

**Option 1: After simulation**
```bash
make sim
make wave
```

**Option 2: Direct GTKWave**
```bash
gtkwave build/axi_reg_if.vcd &
```

### What to Check

#### 1. **AXI Write Transaction**

Look for this pattern:
```
Time   | awvalid | awready | awaddr    | wvalid | wready | wdata      | bvalid | bready |
-------|---------|---------|-----------|--------|--------|------------|--------|--------|
0      |    0    |    x    |    x      |   0    |   x    |     x      |   0    |   1    |
1      |    1    |    0    | 0x4000_00 |   1    |   0    | 0xDEADBEEF |   0    |   1    |
2      |    1    |    1    | 0x4000_00 |   1    |   1    | 0xDEADBEEF |   0    |   1    | ← Handshake
3      |    0    |    1    |    x      |   0    |   1    |     x      |   1    |   1    | ← Response
4      |    0    |    1    |    x      |   0    |   1    |     x      |   0    |   1    | ← Complete
```

**✅ Good signs:**
- `awvalid` and `awready` both high = address accepted
- `wvalid` and `wready` both high = data accepted
- `bvalid` goes high after write = response ready
- `bresp` = 2'b00 = OKAY response

**❌ Warning signs:**
- `bvalid` stays high for multiple cycles (master not accepting response)
- `bresp` != 2'b00 (error response)

#### 2. **AXI Read Transaction**

```
Time   | arvalid | arready | araddr    | rvalid | rready | rdata      | rresp |
-------|---------|---------|-----------|--------|--------|------------|-------|
0      |    0    |    x    |    x      |   0    |   1    |     x      |  x    |
1      |    1    |    0    | 0x4000_00 |   0    |   1    |     x      |  x    |
2      |    1    |    1    | 0x4000_00 |   0    |   1    |     x      |  x    | ← Address accepted
3      |    0    |    1    |    x      |   1    |   1    | 0xDEADBEEF | 2'b00 | ← Data ready
4      |    0    |    1    |    x      |   0    |   1    |     x      |  x    | ← Complete
```

**✅ Good signs:**
- `rvalid` goes high 1 cycle after address accepted
- `rdata` contains expected value
- `rresp` = 2'b00 = OKAY

**❌ Warning signs:**
- `rdata` doesn't match written data
- `rresp` != 2'b00

#### 3. **Register Updates**

After a write to address `0x4000_0004` (register 1):
```
Time   | awaddr    | wdata      | regs_out[63:32] (reg 1)
-------|-----------|------------|---------------------
0      |    x      |     x      | 32'h0000_0000
5      | 0x4000_04 | 0x1234_5678|                       ← Write happens
6      |    x      |     x      | 32'h1234_5678         ← Register updated
```

---

## 🏗️ Synthesis

### Xilinx Vivado

#### GUI Method

1. **Open Vivado**
   ```bash
   vivado &
   ```

2. **Create New Project**
   - Click "Create Project"
   - Name: `axi4lite_peripheral`
   - Type: RTL Project
   - Don't specify sources yet

3. **Add Design Sources**
   - Add Design Sources → Add Files
   - Select: `rtl/axil_reg_if.v`
   - Select: `rtl/gpio_controller.v` (if using GPIO example)

4. **Add Testbench** (for simulation)
   - Add Simulation Sources → Add Files
   - Select: `tb/axil_reg_if_tb.v`

5. **Select Device**
   - Choose your FPGA part number
   - Example: `xc7a35tcpg236-1` (Arty A7-35T)

6. **Run Synthesis**
   - Flow Navigator → Synthesis → Run Synthesis
   - Wait for completion (~2-5 minutes)

7. **Check Results**
   - Open Synthesized Design
   - Check timing: Reports → Timing → Report Timing Summary
   - Check utilization: Reports → Utilization

**Expected Results:**
```
Utilization (8 registers, Artix-7):
  LUTs: ~250-300
  FFs:  ~150-200
  
Timing:
  Worst Negative Slack (WNS): > 0 ns (meeting timing)
  Maximum Frequency: > 100 MHz
```

#### TCL Script Method

Create `vivado_synth.tcl`:
```tcl
# Create project
create_project axi_synth ./vivado_project -part xc7a35tcpg236-1 -force

# Add sources
add_files rtl/axil_reg_if.v
add_files rtl/gpio_controller.v
add_files -fileset sim_1 tb/axil_reg_if_tb.v

# Set top module
set_property top axil_reg_if [current_fileset]

# Run synthesis
launch_runs synth_1
wait_on_run synth_1

# Open and report
open_run synth_1
report_timing_summary -file ./timing_summary.rpt
report_utilization -file ./utilization.rpt

puts "Synthesis complete!"
```

Run it:
```bash
vivado -mode batch -source vivado_synth.tcl
```

---

### Intel Quartus Prime

#### GUI Method

1. **Open Quartus Prime**
   ```bash
   quartus &
   ```

2. **New Project Wizard**
   - File → New Project Wizard
   - Directory: Current directory
   - Name: `axi4lite_peripheral`
   - Top-Level Entity: `axil_reg_if`

3. **Add Files**
   - Add Files → Browse
   - Select `rtl/axil_reg_if.v`
   - Select `rtl/gpio_controller.v` (optional)

4. **Select Device**
   - Choose your FPGA family (Cyclone V, etc.)
   - Select specific device

5. **Compile**
   - Processing → Start Compilation
   - Wait for completion

6. **Check Results**
   - Tools → Netlist Viewers → RTL Viewer
   - Compilation Report → Flow Summary

---

### Yosys (Open Source)

```bash
# Install yosys (if needed)
sudo apt install yosys

# Create synthesis script
cat > synth.ys << 'EOF'
# Read design
read_verilog rtl/axil_reg_if.v

# Synthesize
synth -top axil_reg_if

# Write netlist
write_verilog synth_output.v

# Statistics
stat
EOF

# Run synthesis
yosys synth.ys

# View statistics
cat synth_output.v
```

---

## ✅ Verification Checklist

**Functional:**
- [ ] All 18 tests pass
- [ ] Back-to-back reads/writes work
- [ ] Byte strobes work
- [ ] DECERR on unmapped addresses

**Waveform:**
- [ ] AXI handshakes correct
- [ ] No X/Z values on outputs
- [ ] Ready doesn't depend on valid combinationally

**Synthesis:**
- [ ] No errors or latches
- [ ] Timing met (if constrained)
- [ ] Reasonable utilization

---

## 🐛 Troubleshooting

**Syntax errors:** `iverilog -t null rtl/axil_reg_if.v`
**Tests fail:** `make wave` and check signals
**No waveform:** Run `make sim` first
**Verilator errors:** Delays are testbench-only, safe to ignore for RTL

---

*For complete details, see DESIGN_GUIDE.md and README.md*

| Simulator | Compile Time | Run Time | Total |
|-----------|--------------|----------|-------|
| iverilog  | ~1 second    | ~1 second| ~2s   |
| Verilator | ~5 seconds   | ~0.1s    | ~5s   |
| Vivado    | ~30 seconds  | ~2s      | ~32s  |

Expected synthesis times:

| Tool     | Device      | Synthesis Time | Implementation Time |
|----------|-------------|----------------|---------------------|
| Vivado   | Artix-7     | ~2 minutes     | ~3 minutes          |
| Quartus  | Cyclone V   | ~3 minutes     | ~5 minutes          |
| Yosys    | Generic     | ~10 seconds    | N/A                 |

---

## 🎯 Next Steps

1. **✅ Run first simulation:** `make sim`
2. **👀 View waveforms:** `make wave`
3. **🔧 Customize design:** Edit parameters in `rtl/axil_reg_if.v`
4. **🏗️ Synthesize:** Follow tool-specific guide above
5. **📦 Integrate:** Use in your SoC project

---

## 🆘 Getting Help

If you encounter issues:

1. Check this guide first
2. Review waveforms with `make wave`
3. Look at test output carefully
4. Check tool versions (iverilog 10+, Verilator 4+)
5. Open an issue on GitHub with:
   - Command you ran
   - Error message
   - Tool versions

---

**Happy Verifying! 🎉**

*Last updated: January 2026*
