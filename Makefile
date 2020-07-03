.PHONY: help

help:
	@echo "Makefile Usage:"
	@echo "  make all DEVICE=<FPGA platform> INTERFACE=<CMAC Interface> XCLBIN_NAME=<XCLBIN name>"
	@echo "      Command to generate the xo for specified device and Interface."
	@echo "      By default, DEVICE=xilinx_u280_xdma_201920_3, INTERFACE=0 and XCLBIN_NAME=xup_vitis_networking "
	@echo ""
	@echo "  make clean "
	@echo "      Command to remove the generated non-hardware files."
	@echo ""
	@echo "  make distclean"
	@echo "      Command to remove all the generated files."
	@echo ""


DEVICE ?= xilinx_u280_xdma_201920_3
INTERFACE ?= 0
XCLBIN_NAME ?= xup_vitis_networking

XSA := $(strip $(patsubst %.xpfm, % , $(shell basename $(DEVICE))))
TEMP_DIR := _x.$(XSA)
VPP := $(XILINX_VITIS)/bin/v++
CLFLAGS += -t hw --platform $(DEVICE) --save-temps

BUILD_DIR := ./build_dir.$(XSA)
BINARY_CONTAINERS = $(BUILD_DIR)/${XCLBIN_NAME}.xclbin

NETLAYERDIR = NetLayers
CMACDIR     = Ethernet
KERNELDIR   = Kernels

POSTSYSLINKTCL ?= $(shell readlink -f ./post_sys_link.tcl)
CMAC_IP_FOLDER ?= $(shell readlink -f ./$(CMACDIR)/cmac)

LIST_XO := $(CMACDIR)/$(TEMP_DIR)/cmac_$(INTERFACE).xo
LIST_XO += $(NETLAYERDIR)/$(TEMP_DIR)/networklayer.xo
LIST_XO += $(KERNELDIR)/$(TEMP_DIR)/krnl_mm2s.xo
LIST_XO += $(KERNELDIR)/$(TEMP_DIR)/krnl_s2mm.xo

CONFIGFLAGS := --config connectivity.ini --config advanced.ini

# Linker params
# Linker userPostSysLinkTcl param
ifeq (u250,$(findstring u250, $(DEVICE)))
	#CONFIGFLAGS += --config advanced.ini
	HLS_IP_FOLDER  = $(shell readlink -f ./$(NETLAYERDIR)/100G-fpga-network-stack-core/synthesis_results_noHMB)
endif
ifeq (u280,$(findstring u280, $(DEVICE)))
	#CONFIGFLAGS += --config advanced.ini
	HLS_IP_FOLDER  = $(shell readlink -f ./$(NETLAYERDIR)/100G-fpga-network-stack-core/synthesis_results_HMB)
endif


LIST_REPOS := --user_ip_repo_paths $(CMAC_IP_FOLDER)
LIST_REPOS += --user_ip_repo_paths $(HLS_IP_FOLDER)



.PHONY: all clean distclean 
all: check-devices check-vitis check-xrt $(BINARY_CONTAINERS)


# Cleaning stuff
clean:
	rm -rf *v++* *.log *.jou

distclean: clean
	rm -rf _x* .Xil ./build_dir* .ipcache/


# Building kernel
$(BUILD_DIR)/${XCLBIN_NAME}.xclbin: $(LIST_XO)
	mkdir -p $(BUILD_DIR)
	make -C $(CMACDIR) all DEVICE=$(DEVICE) INTERFACE=$(INTERFACE)
	make -C $(NETLAYERDIR) all DEVICE=$(DEVICE)
	make -C $(KERNELDIR) all DEVICE=$(DEVICE)
	sed -i 's|PATHTOTCLFILE|'"$(POSTSYSLINKTCL)"'|g' advanced.ini
	$(VPP) $(CLFLAGS) $(CONFIGFLAGS) --temp_dir $(BUILD_DIR) -l -o'$@' $(+) $(LIST_REPOS) -j 8
#	--dk chipscope:networklayer_1:S_AXIL_nl \
#	--dk chipscope:krnl_mm2s_1:k2n \
#	--dk chipscope:krnl_s2mm_1:n2k
#	--dk chipscope:krnl_mm2s_1:s_axi_control \
#	--dk chipscope:krnl_s2mm_1:s_axi_control \

check-devices:
ifndef DEVICE
	$(error DEVICE not set. Please set the DEVICE properly and rerun. Run "make help" for more details.)
endif

#Checks for XILINX_VITIS
check-vitis:
ifndef XILINX_VITIS
	$(error XILINX_VITIS variable is not set, please set correctly and rerun)
endif

#Checks for XILINX_XRT
check-xrt:
ifndef XILINX_XRT
	$(error XILINX_XRT variable is not set, please set correctly and rerun)
endif