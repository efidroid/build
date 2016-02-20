# useful macros
FILTER_OUT = $(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))

# disable all debug features by default
DEFINES := $(filter-out WITH_DEBUG_DCC=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_UART=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_FBCON=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_JTAG=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_LOG_BUF=1,$(DEFINES))

# set debug level
DEBUG := 1

ifeq ($(WITH_KERNEL_UEFIAPI),1)
	# add our modules
	MODULES += \
		$(EFIDROID_TOP)/uefi/lkmodules/uefiapi

	# enable the UEFIAPI
	DEFINES += WITH_KERNEL_UEFIAPI=1

	DEFINES += LCD_DENSITY=$(LCD_DENSITY)
	DEFINES += LCD_VRAM_SIZE=$(LCD_VRAM_SIZE)
	CFLAGS += -DDEVICE_NVVARS_PARTITION=\"$(DEVICE_NVVARS_PARTITION)\"

    # disable LK debugging
    DEBUG := 0
else
    DEFINES += WITH_DEBUG_LOG_BUF=1

    ifeq ($(EFIDROID_BUILD_TYPE),DEBUG)
        DEBUG := 2
        DEFINES += LK_LOG_BUF_SIZE=16384
    endif
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

DEFINES += EFIDROID_SAFEBOOT=1
