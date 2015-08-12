EDK2_DIR := $(PWD)/$(TOPDIR)/uefi/edk2
EDK2_OUT := $(PWD)/$(TARGET_OUT)/edk2
EDK2_ENV := GCC48_ARM_PREFIX=$(GCC_LINUX_GNUEABI) MAKEFLAGS=
EDK2_BIN := $(EDK2_OUT)/Build/LittleKernelPkg/DEBUG_GCC48/FV/LITTLEKERNELPKG_EFI.fd

.PHONY: edk2
edk2:
	${call logi,EDK2: compile}
	mkdir -p $(EDK2_OUT)
	$(TOPDIR)build/tools/edk2_update "$(EDK2_DIR)" "$(EDK2_OUT)" "$(PWD)/$(TOPDIR)/uefi/LittleKernelPkg"
	
	MAKEFLAGS= $(MAKE) -C $(EDK2_OUT)/BaseTools
	cd $(EDK2_OUT) && \
		source edksetup.sh && \
		$(EDK2_ENV) build -v -n4 -a ARM -t GCC48 -p LittleKernelPkg/LittleKernelPkg.dsc

.PHONY: edk2_clean
edk2_clean:
	${call logi,EDK2: clean}
	rm -Rf $(EDK2_OUT)/*

.PHONY: edk2_distclean
edk2_distclean: edk2_clean

$(call add-clean-step,edk2_clean)
$(call add-distclean-step,edk2_distclean)
