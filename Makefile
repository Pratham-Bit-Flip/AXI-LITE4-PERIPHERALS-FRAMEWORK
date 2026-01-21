# Makefile for AXI4-Lite Peripheral Framework
# Targets: sim, sim-verilator, clean, docs

.PHONY: all sim sim-verilator clean docs help

# Directories
RTL_DIR := rtl
TB_DIR := tb
DOC_DIR := doc
BUILD_DIR := build
BUILD_VER_DIR := build_verilator

# Tools
IVERILOG := iverilog
VVP := vvp
VERILATOR := verilator
GTKWAVE := gtkwave

# Default target
help:
	@echo "========================================="
	@echo "  AXI4-Lite Peripheral - Makefile"
	@echo "========================================="
	@echo ""
	@echo "Targets:"
	@echo "  make sim          - Run simulation with iverilog"
	@echo "  make sim-verilator - Run simulation with Verilator (10x faster)"
	@echo "  make wave         - View waveform with GTKWave"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make docs         - Show documentation"
	@echo "  make help         - Show this message"
	@echo ""

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Simulation with iverilog
sim: $(BUILD_DIR)
	@echo "========================================="
	@echo "  Compiling with iverilog..."
	@echo "========================================="
	$(IVERILOG) -o $(BUILD_DIR)/tb.vvp \
		$(RTL_DIR)/axil_reg_if.v \
		$(RTL_DIR)/gpio_controller.v \
		$(TB_DIR)/axil_reg_if_tb.v
	@echo "[OK] Compilation successful"
	@echo ""
	@echo "========================================="
	@echo "  Running simulation..."
	@echo "========================================="
	cd $(BUILD_DIR) && $(VVP) tb.vvp
	@echo ""
	@echo "========================================="
	@echo "  Waveform saved to: $(BUILD_DIR)/axi_reg_if.vcd"
	@echo "========================================="

# Simulation with Verilator (faster)
sim-verilator: $(BUILD_VER_DIR)
	@echo "========================================="
	@echo "  Verilating design..."
	@echo "========================================="
	cd $(BUILD_VER_DIR) && \
	$(VERILATOR) --cc --exe --trace \
		../$(RTL_DIR)/axil_reg_if.v \
		../$(TB_DIR)/axil_reg_if_tb.v \
		-o axi_tb
	@echo "[OK] Verilation successful"
	@echo ""
	@echo "========================================="
	@echo "  Building C++ simulation..."
	@echo "========================================="
	make -C $(BUILD_VER_DIR)/obj_dir -f Vaxil_reg_if_tb.mk
	@echo "[OK] Build successful"
	@echo ""
	@echo "========================================="
	@echo "  Running simulation..."
	@echo "========================================="
	cd $(BUILD_VER_DIR) && ./axi_tb
	@echo ""
	@echo "========================================="
	@echo "  Waveform saved to: $(BUILD_VER_DIR)/axi_reg_if.vcd"
	@echo "========================================="

$(BUILD_VER_DIR):
	@mkdir -p $(BUILD_VER_DIR)

# View waveform
wave: 
	@if [ -f "$(BUILD_DIR)/axi_reg_if.vcd" ]; then \
		$(GTKWAVE) $(BUILD_DIR)/axi_reg_if.vcd &; \
	else \
		echo "No waveform found. Run 'make sim' first."; \
	fi

# Show documentation
docs:
	@echo "========================================="
	@echo "  AXI4-Lite Peripheral - Documentation"
	@echo "========================================="
	@echo ""
	@echo "Files:"
	@echo "  README.md          - Project overview and quick start"
	@echo "  QUICKSTART.md      - 5-minute quick start guide"
	@echo "  DESIGN_GUIDE.md    - Detailed architecture and design"
	@echo "  SYNTHESIS.md       - Synthesis and implementation tips"
	@echo ""
	@echo "To view a file:"
	@echo "  cat $(DOC_DIR)/README.md | less"
	@echo ""

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(BUILD_VER_DIR)
	@echo "[OK] Clean complete"

# All (default: run simulation)
all: sim

.SILENT: help
