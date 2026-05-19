VERSION_MAJ = 1
VERSION_MIN = 838

# You must have:
# sudo apt-get install \
pkg-config libglib2.0-dev libfftw3-dev libsndfile1-dev zlib1g-dev libsqlite3-dev libconfig-dev

# --- Compiler ---
CC       ?= gcc
CXX      ?= g++
# CC       ?= clang
# CXX      ?= clang++
OBJCOPY  ?= objcopy
STRIP    ?= strip
PKG_CONFIG ?= pkg-config

# --- Host Compiler ---
BUILD_CXX  ?= g++

# --- Colors ---
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

# --- Misc ---
REPO_NAME = kiwid
REPO_PATH = $(shell pwd)
REPO_GIT = https://github.com/luftkode/$(REPO_NAME)
GITHUB_IP = "140.82.121.3"
HOST_NAME = "kiwisdr"

# --- Includes ---
INCLUDES = -I. -I$(GEN_DIR) $(addprefix -I,$(ALL_DIRS)) -I/usr/include/fftw3

# --- Compiler Flags ---
override DEFS += \
	-DVERSION_MAJ=$(VERSION_MAJ) \
	-DVERSION_MIN=$(VERSION_MIN) \
	-DKIWI \
	-DKIWISDR \
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
	-DMG_ENABLE_THREADS \
	-DHAVE_STDINT_H=1 \
	-D__UINT64_FMTx__=\"llx\"

# --- FFTW3 Compiler Flags ---
FFTW_CFLAGS := $(shell $(PKG_CONFIG) --cflags fftw3f 2>/dev/null || echo "-I/usr/include")
FFTW_LIBS   := $(shell $(PKG_CONFIG) --libs fftw3f 2>/dev/null || echo "-lfftw3f")

# --- GLIB Compiler Flags (Required by HFDL extension) ---
GLIB_CFLAGS := $(shell $(PKG_CONFIG) --cflags glib-2.0 2>/dev/null || echo "-I/usr/include/glib-2.0 -I/usr/lib/arm-linux-gnueabihf/glib-2.0/include -I/usr/lib/aarch64-linux-gnu/glib-2.0/include")
GLIB_LIBS   := $(shell $(PKG_CONFIG) --libs glib-2.0 2>/dev/null || echo "-lglib-2.0")

# --- Other Flags ---
INTERNAL_CFLAGS = $(DEFS) $(INCLUDES) $(FFTW_CFLAGS) $(GLIB_CFLAGS) -O3 -g -pthread -include sys/wait.h 
INTERNAL_LDFLAGS = $(FFTW_LIBS) $(GLIB_LIBS) -lutil -lcrypt -lrt -lpthread -lm

# --- All Flags Combined ---
ALL_CXXFLAGS = $(CXXFLAGS) $(INTERNAL_CFLAGS)
ALL_CFLAGS   = $(CFLAGS) $(INTERNAL_CFLAGS)
ALL_LDFLAGS  = $(LDFLAGS) $(INTERNAL_LDFLAGS)

# --- Source File Directories ---
ALL_DIRS := \
	. \
	./cfg \
	./dev \
	./dx \
	./extensions \
	./extensions/ALE_2G \
	./extensions/colormap \
	./extensions/CW_decoder \
	./extensions/CW_skimmer \
	./extensions/devl \
	./extensions/digi_modes \
	./extensions/DRM/dream/resample \
	./extensions/FAX \
	./extensions/FFT \
	./extensions/FSK \
	./extensions/FT8 \
	./extensions/FT8/ft8_lib/ \
	./extensions/FT8/ft8_lib/common \
	./extensions/FT8/ft8_lib/fft \
	./extensions/FT8/ft8_lib/ft8 \
	./extensions/IBP_scan \
	./extensions/iframe \
	./extensions/IQ_display \
	./extensions/Loran_C \
	./extensions/NAVTEX \
	./extensions/prefs \
	./extensions/S_meter \
	./extensions/s4285 \
	./extensions/sig_gen \
	./extensions/SSTV \
	./extensions/TDoA \
	./extensions/timecode \
	./extensions/wspr \
	./gps \
	./gps/GNSS-SDRLIB \
	./gps/ka9q-fec \
	./net \
	./pkgs/ant_switch \
	./pkgs/jsmn \
	./pkgs/mongoose \
	./pkgs/parson \
	./pkgs/sdrpp_server \
	./pkgs/sha256 \
	./pkgs/TNT_JAMA \
	./pkgs/TNT_JAMA/jama \
	./pkgs/TNT_JAMA/tnt \
	./pkgs/utf8 \
	./platform \
	./platform/common \
	./platform/raspberrypi \
	./rx \
	./rx/CMSIS \
	./rx/csdr \
	./rx/CuteSDR \
	./rx/fldigi \
	./rx/fldigi/mfsk \
	./rx/fldigi/rsid \
	./rx/kiwi \
	./rx/Teensy \
	./rx/wdsp \
	./support \
	./ui \
	./web

# --- Source Files ---
SOURCES_CPP = $(foreach dir,$(ALL_DIRS),$(wildcard $(dir)/*.cpp))
SOURCES_C   = $(foreach dir,$(ALL_DIRS),$(wildcard $(dir)/*.c))
# Filter out web.cpp from standard discovery because it needs special defines
SOURCES_CPP := $(filter-out ./web/web.cpp, $(SOURCES_CPP))

# --- Special Files ---
KIWI_SPECIAL_OBJS = \
    $(OBJ_DIR)/web/web_embed.o \
    $(OBJ_DIR)/ext_init.o \
    $(OBJ_DIR)/edata_embed.o \
    $(OBJ_DIR)/edata_always.o

# --- Object Files ---
OBJECTS_CPP = $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(SOURCES_CPP))
OBJECTS_C   = $(patsubst %.c,$(OBJ_DIR)/%.o,$(SOURCES_C))
ALL_OBJECTS = $(OBJECTS_CPP) $(OBJECTS_C) $(KIWI_SPECIAL_OBJS)

# Generate VPATH so make can find the sources
vpath %.cpp $(ALL_DIRS)
vpath %.c   $(ALL_DIRS)

# ---------- Recipes ----------
clean_build: clean build

build: $(BIN)

clean:
	@echo "$(G)Cleaning build directory...$(N)"
	@rm -rf $(BUILD_DIR)

# --- Header Generation and Softcore/e_cpu Assembling ---
GEN_HEADERS = $(GEN_DIR)/kiwi.gen.h

# All compiled objects depend on the generated header being present first
$(ALL_OBJECTS): $(GEN_HEADERS) $(GEN_DIR)/ext_init.cpp

$(GEN_HEADERS):
	@$(MAKE) -C e_cpu gen \
		BUILD_CXX="$(BUILD_CXX)" \
		BUILD_DIR="../$(BUILD_DIR)" \
		GEN_DIR="../$(GEN_DIR)"

# --- Extension initialiser ---
# Automatically discover all extension modules on disk (excluding DRM)
EXT_DIRS := $(sort $(dir $(wildcard extensions/*/)))
EXTS     := $(filter-out DRM, $(notdir $(patsubst %/,%,$(EXT_DIRS))))

$(GEN_DIR)/ext_init.cpp:
	@mkdir -p $(dir $@)
	@echo "$(G)Generating$(N) $@"
	@echo "// auto-generated file -- do not edit by hand" > $@
	@echo "void extint_init() {" >> $@
	@$(foreach ext,$(EXTS),printf "\textern void $(ext)_main(); $(ext)_main();\n" >> $@.tmp;)
	@if [ -f $@.tmp ]; then sort -bdf -f $@.tmp >> $@ && rm -f $@.tmp; fi
	@echo "}" >> $@
	@echo "bool extint_vars() {" >> $@
	@echo "    bool vars = false;" >> $@
	@$(foreach ext,$(EXTS),printf "\textern bool $(ext)_vars(); vars |= $(ext)_vars();\n" >> $@.tmp;)
	@if [ -f $@.tmp ]; then sort -bdf -f $@.tmp >> $@ && rm -f $@.tmp; fi
	@echo "    return vars;" >> $@
	@echo "}" >> $@

# --- Web asset embedding  ---
_EMBED_FILES  := $(patsubst web/%,%,$(FILES_EMBED))
_ALWAYS_FILES := $(patsubst web/%,%,$(FILES_ALWAYS))
 
$(GEN_DIR)/edata_embed.cpp: $(GEN_HEADERS) | $(GEN_DIR)
	@echo "$(G)Generating$(N) $@ ($(words $(FILES_EMBED)) files)"
	@cd web && perl mkdata.pl edata_embed $(FILES_EMBED) > ../$(GEN_DIR)/edata_embed.cpp
 
$(GEN_DIR)/edata_always.cpp: $(GEN_HEADERS) | $(GEN_DIR)
	@echo "$(G)Generating$(N) $@ ($(words $(FILES_ALWAYS)) files)"
	@cd web && perl mkdata.pl edata_always $(FILES_ALWAYS) > ../$(GEN_DIR)/edata_always.cpp
 
$(GEN_DIR):
	@mkdir -p $@

# --- Linking ---
$(BIN): $(ALL_OBJECTS)
	@mkdir -p $(dir $@)
	@echo "$(G)Linking$(N) $@"
	@$(CXX) $(ALL_OBJECTS) $(ALL_LDFLAGS) -o $@

# --- Standard Pattern Rules ---
$(OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CC) $(ALL_CFLAGS) -c $< -o $@

# --- Special Object Rules ---
$(OBJ_DIR)/web/web_embed.o: web/web.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -DEDATA_EMBED -c $< -o $@

$(OBJ_DIR)/ext_init.o: $(GEN_DIR)/ext_init.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/edata_embed.o: $(GEN_DIR)/edata_embed.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/edata_always.o: $(GEN_DIR)/edata_always.cpp
	@mkdir -p $(dir $@)
	@echo "$(G)Compiling$(N) $<"
	@$(CXX) $(ALL_CXXFLAGS) -c $< -o $@

.PHONY: build clean clean_build
