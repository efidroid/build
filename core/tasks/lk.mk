LK_DIR := $(TOPDIR)lk/common/master
LK_OUT := $(TARGET_OUT)/lk
LK_ENV := BOOTLOADER_OUT=$(PWD)/$(LK_OUT) ARCH=arm SUBARCH=arm TOOLCHAIN_PREFIX=$(GCC_EABI)
LK_ENV += MEMBASE=$(LK_BASE) MEMSIZE=0x400000
LK_ENV += LK_EXTERNAL_MAKEFILE=$(PWD)/$(BUILD_SYSTEM)/lk_inc.mk EFIDROID_TOP=$(PWD)/$(TOPDIR)
LK_ENV += EFIDROID_DEVICE_DIR=$(PWD)$(TOPDIR)/device/$(DEVICEID)
LK_ENV_NOUEFI := $(LK_ENV) BOOTLOADER_OUT=$${BOOTLOADER_OUT}-nouefi

LK_ENV += EDK2_BIN=$(EDK2_BIN) EDK2_BASE=$(EDK2_BASE) EDK2_SIZE=$(DRAM_SIZE) EDK2_API_INC=$(PWD)/$(TOPDIR)uefi/edk2packages/LittleKernelPkg/Include
LK_ENV += WITH_KERNEL_UEFIAPI=1
LK_ENV += LCD_DENSITY=$(LCD_DENSITY)

ifneq ($(LK_SOURCE),)
LK_DIR := $(TOPDIR)$(LK_SOURCE)
endif

# lk_check()
define lk_check
$(if $(LK_TARGET),, \
	$(eval $(call loge,LK_TARGET is not set)) \
) \
$(if $(LCD_DENSITY),, \
	$(eval $(call loge,LCD_DENSITY is not set)) \
) \
$(if $(wildcard $(LK_DIR)),, \
	$(eval $(call loge,LK wasn't found at $(LK_DIR))) \
)
endef

.PHONY: lk
lk: edk2
	${call logi,LK: compile}
	mkdir -p $(LK_OUT)
	$(call lk_check)
	
	$(LK_ENV) $(MAKE) -C $(LK_DIR) $(LK_TARGET)

.PHONY: lk_sideload
lk_sideload: lk host_mkbootimg
	$(HOST_OUT)/mkbootimg/mkbootimg \
		--kernel $(LK_OUT)/build-$(LK_TARGET)/lk.bin \
		--ramdisk /dev/null \
		--base $$(printf "0x%x" $$(($(LK_BASE) - 0x8000))) \
		-o $(TARGET_OUT)/lk_sideload.img

.PHONY: lk_clean
lk_clean:
	${call logi,LK: clean}
	$(call lk_check)
	$(LK_ENV) $(MAKE) -C lk $(LK_TARGET) clean

.PHONY: lk_distclean
lk_distclean:
	${call logi,LK: distclean}
	rm -Rf $(LK_OUT)/*

$(call add-clean-step,lk_clean)
$(call add-distclean-step,lk_distclean)


############## NOUEFI BUILD FOR TESTING ##############
.PHONY: lk_nouefi
lk_nouefi:
	${call logi,LK\(no UEFI\): compile}
	mkdir -p $(LK_OUT)-nouefi
	$(call lk_check)
	
	$(LK_ENV_NOUEFI) $(MAKE) -C $(LK_DIR) $(LK_TARGET)

.PHONY: lk_nouefi_sideload
lk_nouefi_sideload: lk_nouefi host_mkbootimg
	$(HOST_OUT)/mkbootimg/mkbootimg \
		--kernel $(LK_OUT)-nouefi/build-$(LK_TARGET)/lk.bin \
		--ramdisk /dev/null \
		--base $$(printf "0x%x" $$(($(LK_BASE) - 0x8000))) \
		-o $(TARGET_OUT)/lk_nouefi_sideload.img

.PHONY: lk_nouefi_clean
lk_nouefi_clean:
	${call logi,LK\(no UEFI\): clean}
	$(call lk_check)
	$(LK_ENV_NOUEFI) $(MAKE) -C lk $(LK_TARGET) clean

.PHONY: lk_nouefi_distclean
lk_nouefi_distclean:
	${call logi,LK\(no UEFI\): distclean}
	rm -Rf $(LK_OUT)-nouefi/*

$(call add-clean-step,lk_nouefi_clean)
$(call add-distclean-step,lk_nouefi_distclean)
