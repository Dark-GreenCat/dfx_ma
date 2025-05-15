# Makefile for compiling and simulating ram_2p with QuestaSim

# Detect OS and set shell
ifeq ($(OS),Windows_NT)
    SHELL := pwsh.exe
    SHELLFLAGS := -NoProfile -Command
    RM := Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
else
    SHELL := /bin/bash
    SHELLFLAGS := -c
    RM := rm -rf
endif

# Tool settings
VLOG = vlog
VSIM = vsim

# Directories
RTL_DIR = rtl
TB_DIR = tb
WORK_DIR = work

# Source files
RTL_SRC = $(RTL_DIR)/ip/ram_2p.sv $(RTL_DIR)/ip/ram_1p.sv $(RTL_DIR)/ma_define.vh $(RTL_DIR)/axi2bram_datamover.sv $(RTL_DIR)/bram2arbiter_datamover.sv $(RTL_DIR)/arbiter.sv $(RTL_DIR)/ma_controller.sv $(RTL_DIR)/ma.sv
TB_SRC = $(TB_DIR)/sim_ram_2p_tb.sv $(TB_DIR)/sim_ram_1p_tb.sv $(TB_DIR)/sim_ma_tb.sv
MEM_FILE = init.mem

# Simulation settings
TOP_MODULE = sim_ma_tb
VSIM_FLAGS = -c -voptargs=+acc=npr
VLOG_FLAGS = -sv
DO_SCRIPT = "vlog $(TB_SRC); vsim $(VSIM_FLAGS) $(TOP_MODULE); run -all"

# Targets
all: compile sim

# Compile source files
compile:
	$(VLOG) $(VLOG_FLAGS) $(RTL_SRC) $(TB_SRC)

# Run simulation
sim:
	$(VSIM) -c -do $(DO_SCRIPT)

# Clean generated files
clean:
	$(RM) $(WORK_DIR)
	$(RM) transcript
	$(RM) *.vcd

wave:
	gtkwave $(TOP_MODULE).vcd &

.PHONY: all compile sim clean
