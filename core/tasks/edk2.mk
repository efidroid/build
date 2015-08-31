EDK2_DIR := $(PWD)/$(TOPDIR)/uefi/edk2
EDK2_OUT := $(PWD)/$(TARGET_OUT)/edk2
EDK2_ENV := GCC49_ARM_PREFIX=$(GCC_LINUX_GNUEABI) MAKEFLAGS=
EDK2_BIN := $(EDK2_OUT)/Build/LittleKernelPkg/DEBUG_GCC49/FV/LITTLEKERNELPKG_EFI.fd
EDK2_EFIDROID_OUT := $(EDK2_OUT)/Build/EFIDROID
EDK2_FDF_INC := $(EDK2_EFIDROID_OUT)/LittleKernelPkg.fdf.inc

FILTER_OUT = $(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))

# default values
DRAM_BASE ?= $(EDK2_BASE)
DRAM_SIZE ?= 0x01000000 # 16MB

# LK + LKSIZE + FRAMEBUFFER(8MB for now)
EDK2_BASE ?= $(shell printf "0x%x" $$(($(LK_BASE) + 0x400000 + 0x800000)))

.PHONY: edk2
edk2:
	${call logi,EDK2: compile}
	
	# check variables
	$(if $(EDK2_BASE),,$(eval $(call loge,EDK2_BASE is not set)))
	$(if $(DRAM_BASE),,$(eval $(call loge,DRAM_BASE is not set)))
	$(if $(DRAM_SIZE),,$(eval $(call loge,DRAM_SIZE is not set)))
	
	# setup build directory
	mkdir -p $(EDK2_OUT)
	mkdir -p $(EDK2_EFIDROID_OUT)
	$(TOPDIR)build/tools/edk2_update "$(EDK2_DIR)" "$(EDK2_OUT)" "$(PWD)/$(TOPDIR)/uefi/LittleKernelPkg"
	
	# generate FDF include file
	echo -e "DEFINE FD_BASE = $(EDK2_BASE)\n" > $(EDK2_FDF_INC)
	
	# get EDK git revision
	$(eval EDK2_VERSION := $(shell cd $(EDK2_DIR) && git rev-parse --verify --short HEAD))
	
	# (re)compile BaseTools
	MAKEFLAGS= $(MAKE) -C $(EDK2_OUT)/BaseTools
	
	# compile EDKII
	# Note: using 4 threads here as this seems to be a generic value
	# and the build system ignores this makefile's settings
	cd $(EDK2_OUT) && \
		source edksetup.sh && \
		$(EDK2_ENV) build -n4 -a ARM -t GCC49 -p LittleKernelPkg/LittleKernelPkg.dsc \
			-DFIRMWARE_VER=$(EDK2_VERSION) \
			-DFIRMWARE_VENDOR=EFIDroid \
			-DDRAM_BASE=$(DRAM_BASE) \
			-DDRAM_SIZE=$(DRAM_SIZE) ${COLORIZE}
	
	# force rebuild of LK
	touch $(TOPDIR)uefi/lkmodules/uefiapi/edk2bin.c

.PHONY: edk2_shell
edk2_shell:
	cd $(EDK2_OUT) && \
		source edksetup.sh && \
		$(EDK2_ENV) bash

.PHONY: edk2_clean
edk2_clean:
	${call logi,EDK2: clean}
	rm -Rf $(EDK2_OUT)/*

.PHONY: edk2_distclean
edk2_distclean: edk2_clean

$(call add-clean-step,edk2_clean)
$(call add-distclean-step,edk2_distclean)
