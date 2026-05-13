# Pure Makefile for KiwiSDR embedded CPU assembler
# Removed legacy includes for Yocto compatibility

# Standard toolchain defaults
CXX ?= g++
STRIP ?= strip

# Paths (passed from parent or defaulted)
BUILD_DIR ?= ../build
TOOLS_DIR = $(BUILD_DIR)/tools
GEN_DIR = $(BUILD_DIR)/gen
KIWI_SRC = ..

# ASM tool configuration
ASM = $(TOOLS_DIR)/asm
ASM_SOURCE = $(wildcard asm/*.cpp)
ASM_INCLUDES = $(wildcard asm/*.h)

# CXXFLAGS for the host tool (asm)
INTERNAL_CXXFLAGS = -I. -I./asm -I.. -I$(KIWI_SRC) -D_GNU_SOURCE -g

.PHONY: all gen clean

all: $(ASM) gen

# The generator tool itself
$(ASM): $(ASM_SOURCE) $(ASM_INCLUDES)
	@mkdir -p $(TOOLS_DIR)
	@mkdir -p $(GEN_DIR)
	$(CXX) $(CXXFLAGS) $(INTERNAL_CXXFLAGS) $(ASM_SOURCE) -o $@
	$(STRIP) $@

# Generate the headers required for the main build
gen: $(ASM)
	@mkdir -p $(GEN_DIR)
	$(ASM) -o $(GEN_DIR) $(OTHER_DIR)

clean:
	rm -f $(ASM)