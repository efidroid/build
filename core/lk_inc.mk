# disable all debug features by default
DEFINES := $(filter-out WITH_DEBUG_DCC=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_UART=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_FBCON=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_JTAG=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_LOG_BUF=1,$(DEFINES))

ifeq ($(WITH_KERNEL_UEFIAPI),1)
	# add our modules
	MODULES += \
		$(EFIDROID_TOP)/uefi/lkmodules/uefiapi

	# enable the UEFIAPI
	DEFINES += WITH_KERNEL_UEFIAPI=1

	DEFINES += LCD_DENSITY=$(LCD_DENSITY)
	CFLAGS += -DDEVICE_NVVARS_PARTITION=\"$(DEVICE_NVVARS_PARTITION)\"

else
DEFINES += WITH_DEBUG_LOG_BUF=1
endif

# optionally include device specific makefile
-include $(EFIDROID_DEVICE_DIR)/lk_inc.mk

# automatically set cflags for known configs
ifeq ($(EMMC_BOOT),1)
  CFLAGS += -D_EMMC_BOOT=1
endif

ifeq ($(SIGNED_KERNEL),1)
  CFLAGS += -D_SIGNED_KERNEL=1
endif

ifeq ($(TARGET_BUILD_VARIANT),user)
  CFLAGS += -DDISABLE_FASTBOOT_CMDS=1
endif

DEFINES += EFIDROID_2NDSTAGE=1
DEFINES += EFIDROID_SAFEBOOT=1
