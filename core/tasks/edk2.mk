EDK2_DIR := $(PWD)/$(TOPDIR)/uefi/edk2
EDK2_OUT := $(PWD)/$(TARGET_OUT)/edk2
EDK2_ENV := GCC49_ARM_PREFIX=$(GCC_LINUX_GNUEABI) MAKEFLAGS=
EDK2_BIN := $(EDK2_OUT)/Build/LittleKernelPkg/DEBUG_GCC49/FV/LITTLEKERNELPKG_EFI.fd
EDK2_EFIDROID_OUT := $(EDK2_OUT)/Build/EFIDROID
EDK2_LIBLK := $(EDK2_EFIDROID_OUT)/liblk.o
EDK2_LIBLK_SYMS := $(EDK2_LIBLK).syms
EDK2_FDF_INC := $(EDK2_EFIDROID_OUT)/LittleKernelPkg.fdf.inc

FILTER_OUT = $(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))

# default values
DRAM_BASE ?= $(EDK2_BASE)
DRAM_SIZE ?= 0x01000000 # 16MB

.PHONY: edk2
edk2: lk
	${call logi,EDK2: compile}
	
	# check variables
	$(if $(EDK2_BASE),,$(eval $(call loge,EDK2_BASE is not set)))
	$(if $(DRAM_BASE),,$(eval $(call loge,DRAM_BASE is not set)))
	$(if $(DRAM_SIZE),,$(eval $(call loge,DRAM_SIZE is not set)))
	
	mkdir -p $(EDK2_OUT)
	mkdir -p $(EDK2_EFIDROID_OUT)
	$(TOPDIR)build/tools/edk2_update "$(EDK2_DIR)" "$(EDK2_OUT)" "$(PWD)/$(TOPDIR)/uefi/LittleKernelPkg"
	
	# create list of objects for liblk
	$(eval LIBLKOBJS = $(shell find $(LK_OUT) -name *.o))
	$(eval LIBLKOBJS = $(call FILTER_OUT,$(LK_OUT)/build-$(LK_TARGET)/app,$(LIBLKOBJS)))
	$(eval LIBLKOBJS = $(call FILTER_OUT,$(LK_OUT)/build-$(LK_TARGET)/arch,$(LIBLKOBJS)))
	$(eval LIBLKOBJS = $(call FILTER_OUT,$(LK_OUT)/build-$(LK_TARGET)/lib/heap,$(LIBLKOBJS)))
	$(eval LIBLKOBJS = $(call FILTER_OUT,$(LK_OUT)/build-$(LK_TARGET)/kernel,$(LIBLKOBJS)))
	# prefix all symbols (except aeabi ones) with 'lk_'
	$(GCC_EABI)ld -r $(LIBLKOBJS) -o $(EDK2_LIBLK)
	$(GCC_EABI)nm -g $(EDK2_LIBLK) | grep -v __aeabi | xargs -I{} sh -c 'x="{}"; sym=$${x##* };echo $$sym lk_$$sym' > $(EDK2_LIBLK_SYMS)
	$(GCC_EABI)objcopy --redefine-syms $(EDK2_LIBLK_SYMS) $(EDK2_LIBLK)
	
	# generate FDF include file
	echo -e "DEFINE FD_BASE = $(EDK2_BASE)\n" > $(EDK2_FDF_INC)
	
	# get EDK git revision
	$(eval EDK2_VERSION := $(shell cd $(EDK2_DIR) && git rev-parse --verify --short HEAD))
	
	# force rebuild because edk2 can't detect changes to liblk.o
	touch $(EDK2_OUT)/LittleKernelPkg/Library/LittleKernelLib/empty.c
	MAKEFLAGS= $(MAKE) -C $(EDK2_OUT)/BaseTools
	cd $(EDK2_OUT) && \
		source edksetup.sh && \
		$(EDK2_ENV) build -n4 -a ARM -t GCC49 -p LittleKernelPkg/LittleKernelPkg.dsc \
			-DFIRMWARE_VER=$(EDK2_VERSION) \
			-DFIRMWARE_VENDOR=EFIDroid \
			-DDRAM_BASE=$(DRAM_BASE) \
			-DDRAM_SIZE=$(DRAM_SIZE)

edk2_sideload: edk2 host_mkbootimg
	$(HOST_OUT)/mkbootimg/mkbootimg \
		--kernel $(EDK2_BIN) \
		--ramdisk /dev/null \
		--base $$(printf "0x%x" $$(($(EDK2_BASE) - 0x8000))) \
		-o $(TARGET_OUT)/edk2_sideload.img

.PHONY: edk2_clean
edk2_clean:
	${call logi,EDK2: clean}
	rm -Rf $(EDK2_OUT)/*

.PHONY: edk2_distclean
edk2_distclean: edk2_clean

$(call add-clean-step,edk2_clean)
$(call add-distclean-step,edk2_distclean)
