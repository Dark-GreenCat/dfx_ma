# Makefile for compiling and simulating ram_2p with QuestaSim
ifeq ($(OS),Windows_NT)
    SHELL := pwsh.exe
else
   SHELL := pwsh
endif
.SHELLFLAGS := -NoProfile -Command 

# Tool settings
VLOG = vlog
VSIM = vsim

# Directories
RTL_DIR = rtl
TB_DIR = tb
WORK_DIR = work

# Source files
RTL_SRC = $(RTL_DIR)/ip/ram_2p.sv $(RTL_DIR)/ip/ram_1p.sv
TB_SRC = $(TB_DIR)/sim_ram_2p_tb.sv $(TB_DIR)/sim_ram_1p_tb.sv
MEM_FILE = init.mem

# Simulation settings
TOP_MODULE = sim_ram_2p_tb
VSIM_FLAGS = -c -voptargs=+acc=npr
VLOG_FLAGS = -sv
DO_SCRIPT = "vlog $(TB_SRC); vsim $(VSIM_FLAGS) $(TOP_MODULE); run -all"

# System flags
RM_FLAGS = -Force -Recurse -ErrorAction SilentlyContinue

# Targets
all: compile sim

# Compile source files
compile:
	$(VLOG) $(VLOG_FLAGS) $(RTL_SRC) $(TB_SRC)

# Run simulation
sim: compile
	$(VSIM) -c -do $(DO_SCRIPT)

# Clean generated files
clean:
	-rm $(RM_FLAGS) $(WORK_DIR)
	-rm $(RM_FLAGS) transcript
	-rm $(RM_FLAGS) *.vcd

.PHONY: all compile sim clean
