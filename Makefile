VERSION_MAJ = 1
VERSION_MIN = 838

# You must have:
# sudo apt-get install libfftw3-dev libsndfile1-dev zlib1g-dev

# --- Compiler / Toolchain Settings ---
# These ?= assignments allow Yocto to override them via the environment
CC       ?= gcc
CXX      ?= g++
OBJCOPY  ?= objcopy
STRIP    ?= strip
PKG_CONFIG ?= pkg-config


BOLD 	:= 	\033[1m
NORMAL 	:= 	\033[0m
GREEN 	:= 	\033[32m
RED 	:= 	\033[31m

G := $(BOLD)$(GREEN)
B := $(BOLD)
N := $(NORMAL)

# --- Directories ---
BUILD_DIR = build
OBJ_DIR   = $(BUILD_DIR)/obj
GEN_DIR   = $(BUILD_DIR)/gen
BIN       = $(BUILD_DIR)/kiwi.bin

REPO_NAME = kiwid
REPO_PATH = $(shell pwd)
REPO_GIT = https://github.com/luftkode/$(REPO_NAME)

GITHUB_IP = "140.82.121.3"

# --- Source Discovery ---
# Automatically find all directories containing source or header files
# Excludes the build directory and any hidden folders (like .git)
ALL_DIRS := $(shell find . -maxdepth 4 -not -path '*/.*' -not -path './$(OBJ_DIR)*' -type d)

# Standard Includes
INCLUDES = -I. -I$(GEN_DIR) $(addprefix -I,$(ALL_DIRS)) -I/usr/include/fftw3

# --- Flags for Raspberry Pi ---
HOST_NAME = "kiwisdr"

override DEFS += \
	-DVERSION_MAJ=$(VERSION_MAJ) \
	-DVERSION_MIN=$(VERSION_MIN) \
	-DKIWI -DKIWISDR \
	-DPLATFORM_RASPI \
	-DPLATFORM_LINUX \
	-DCPU_BCM2837 \
	-DARCH_CPU_S=\"BCM2837\" \
	-DDIR_CFG=\"/etc/kiwi\" \
	-DDIR_DATA=\"/var/lib/kiwi\" \
	-DCFG_PREFIX=\"\" \
	-DCOMPILE_HOST=\"$(HOST_NAME)\" \
	-DSPI_SHMEM_DISABLE=1 \
    -DBUILD_DIR=\"$(BUILD_DIR)\" \
	-DREPO_NAME=\"$(REPO_NAME)\" \
    -DREPO_DIR=\"$(REPO_PATH)\" \
    -DREPO_GIT=\"$(REPO_GIT)\" \
    -DGITHUB_COM_PUBLIC_IP=\"$(GITHUB_IP)\" \
	-DMONGOOSE_NEW_API \
	-DMG_ENABLE_THREADS

# --- FFTW3 Check ---
# This is the "proper" way to find FFTW3 headers/libs
# If pkg-config fails, it defaults to /usr/include
FFTW_CFLAGS := $(shell $(PKG_CONFIG) --cflags fftw3f 2>/dev/null || echo "-I/usr/include")
FFTW_LIBS   := $(shell $(PKG_CONFIG) --libs fftw3f 2>/dev/null || echo "-lfftw3f")

# Internal Flags
# Added $(FFTW_CFLAGS) to the include list
INTERNAL_CFLAGS = -Wno-builtin-macro-redefined $(DEFS) $(INCLUDES) $(FFTW_CFLAGS) -O3 -g -pthread -include sys/wait.h 
INTERNAL_LDFLAGS = $(FFTW_LIBS) -lutil -lcrypt -lrt -lpthread -lm

# Final variables used in rules
ALL_CXXFLAGS = $(CXXFLAGS) $(INTERNAL_CFLAGS)
ALL_CFLAGS   = $(CFLAGS) $(INTERNAL_CFLAGS)
ALL_LDFLAGS  = $(LDFLAGS) $(INTERNAL_LDFLAGS)

# --- Files ---
# Locate all .cpp and .c files in the defined directories
SOURCES_CPP = $(foreach dir,$(ALL_DIRS),$(wildcard $(dir)/*.cpp))
SOURCES_C   = $(foreach dir,$(ALL_DIRS),$(wildcard $(dir)/*.c))

# Filter out web.cpp from standard discovery because it needs special defines
SOURCES_CPP := $(filter-out web/web.cpp, $(SOURCES_CPP))

# These are the "special" KiwiSDR objects required for a functional build
KIWI_SPECIAL_OBJS = \
    $(OBJ_DIR)/web/web_embed.o \
    $(OBJ_DIR)/ext_init.o \
    $(OBJ_DIR)/edata_embed.o \
    $(OBJ_DIR)/edata_always.o

# Map sources to object files PRESERVING directory structure to avoid collisions
OBJECTS_CPP = $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(SOURCES_CPP))
OBJECTS_C   = $(patsubst %.c,$(OBJ_DIR)/%.o,$(SOURCES_C))

ALL_OBJECTS = $(OBJECTS_CPP) $(OBJECTS_C) $(KIWI_SPECIAL_OBJS)

# Generate VPATH so make can find the sources
vpath %.cpp $(ALL_DIRS)
vpath %.c   $(ALL_DIRS)

# --- Rules ---

clean_build: clean build

build: $(BIN)

GEN_HEADERS = $(GEN_DIR)/kiwi.gen.h

$(ALL_OBJECTS): $(GEN_HEADERS)

$(GEN_HEADERS):
	@echo "$(G)Generating headers...$(N)"
	@$(eval HOST_CXX = $(if $(BUILD_CXX),$(BUILD_CXX),g++))
	@$(MAKE) -C e_cpu gen \
		CXX="$(HOST_CXX)" \
		BUILD_DIR="../$(BUILD_DIR)" \
		GEN_DIR="../$(GEN_DIR)"

# Link the final binary (Now including special objects)
$(BIN): $(ALL_OBJECTS)
	@mkdir -p $(dir $@)
	@echo "$(G)Linking$(N) $@"
	$(CXX) $(ALL_OBJECTS) $(ALL_LDFLAGS) -o $@

# --- Standard Pattern Rules ---
# Pattern rule for C++ files (Preserves directory tree)
$(OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

# Pattern rule for C files (Preserves directory tree)
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CC) $(ALL_CFLAGS) -c $< -o $@

# --- Special KiwiSDR Object Rules ---
# The web server MUST be compiled with EDATA_EMBED for the production kiwid.bin
$(OBJ_DIR)/web/web_embed.o: web/web.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -DEDATA_EMBED -c $< -o $@

# Extension initialization (from your GEN_DIR)
$(OBJ_DIR)/ext_init.o: $(GEN_DIR)/ext_init.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

# Embedded data (the actual website files turned into code)
$(OBJ_DIR)/edata_embed.o: $(GEN_DIR)/edata_embed.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/edata_always.o: $(GEN_DIR)/edata_always.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

clean:
	@echo "$(G)Cleaning build directory...$(N)"
	@rm -rf $(BUILD_DIR)

.PHONY: clean build clean_build
