# Quick Reference Card - Makefile Commands

## 🎯 Essential Commands

```bash
make sim      # Run simulation
make wave     # View waveforms
make clean    # Clean build files
```

---

## 📊 What Each Command Does

| Command | Compiles? | Runs? | Waveform? | Time |
|---------|-----------|-------|-----------|------|
| `make sim` | ✅ Yes | ✅ Yes | ✅ Creates | ~2s |
| `make sim-verilator` | ✅ Yes | ✅ Yes | ✅ Creates | ~5s |
| `make wave` | ❌ No | ❌ No | 👁️ Opens | Instant |
| `make clean` | ❌ No | ❌ No | 🗑️ Deletes | Instant |

---

## 🔄 Workflow

```bash
# Edit RTL
vim rtl/axil_reg_if.v

# Test
make sim

# Debug (if needed)
make wave

# Before commit
make clean
```

---

## 🐛 Troubleshooting

- **Command not found:** `sudo apt install iverilog`
- **No waveform:** Run `make sim` first
- **Tests fail:** `make wave` to debug

---

## 📂 File Locations

After running `make sim`:
```
axi4lite_peripheral/
├── build/
│   ├── tb.vvp           ← Compiled simulation
│   └── axi_reg_if.vcd   ← Waveform data (open with GTKWave)
├── rtl/
│   └── axil_reg_if.v    ← Your design
└── tb/
    └── axil_reg_if_tb.v ← Testbench
```

---

**Most common command:** `make sim` - Run this 90% of the time!
