LK_DIR := $(TOPDIR)lk/common
LK_OUT := $(TARGET_OUT)/lk
LK_ENV := BOOTLOADER_OUT=$(PWD)/$(LK_OUT) ARCH=arm SUBARCH=arm TOOLCHAIN_PREFIX=$(GCC_EABI) EDK2_BIN=$(EDK2_BIN)

ifneq ($(LK_SOURCE),)
LK_DIR := $(LK_SOURCE)
endif

# lk_check()
define lk_check
$(if $(LK_TARGET),, \
	$(eval $(call loge,LK_TARGET is not set)) \
)
endef

.PHONY: lk
lk: edk2
	${call logi,LK: compile}
	mkdir -p $(LK_OUT)
	$(call lk_check)
	$(LK_ENV) $(MAKE) -C $(LK_DIR) $(LK_TARGET)

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
