# disable all debug features by default
DEFINES := $(filter-out WITH_DEBUG_DCC=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_UART=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_FBCON=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_JTAG=1,$(DEFINES))

ifeq ($(WITH_KERNEL_UEFIAPI),1)
	# add our modules
	MODULES += \
		$(EFIDROID_TOP)/uefi/lkmodules/uefiapi

	# enable the UEFIAPI
	DEFINES += WITH_KERNEL_UEFIAPI=1

	DEFINES += LCD_DENSITY=$(LCD_DENSITY)
endif

# optionally include device specific makefile
-include $(EFIDROID_DEVICE_DIR)/lk_inc.mk

DEFINES += EFIDROID_SAFEBOOT=1
