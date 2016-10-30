#
# Copyright (C) 2016 The EFIDroid Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# useful macros
FILTER_OUT = $(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))

EFIDROID_COMMON_DIR := $(EFIDROID_TOP)/bootloader/lk/common/shared

# disable all debug features by default
DEFINES := $(filter-out WITH_DEBUG_DCC=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_UART=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_FBCON=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_JTAG=1,$(DEFINES))
DEFINES := $(filter-out WITH_DEBUG_LOG_BUF=1,$(DEFINES))

# set debug level
DEBUG := 1

# add our modules
MODULES += \
    $(EFIDROID_COMMON_DIR)/fastboot \
    $(EFIDROID_COMMON_DIR)/lib/base64 \
    $(EFIDROID_COMMON_DIR)/lib/hex2unsigned \
    $(EFIDROID_COMMON_DIR)/lib/atagparse

DEFINES += WITH_FASTBOOT_EXT=1
DEFINES += WITH_LIB_BASE64=1
DEFINES += WITH_LIB_ATAGPARSE=1

# disable secure stuff
DEFINES := $(filter-out VERIFIED_BOOT=1,$(DEFINES))
DEFINES := $(filter-out MDTP_SUPPORT=1,$(DEFINES))
DEFINES += VERIFIED_BOOT=0
ENABLE_MDTP_SUPPORT := 0

ifeq ($(WITH_KERNEL_UEFIAPI),1)
    # add our modules
    MODULES += \
        $(EFIDROID_COMMON_DIR)/uefiapi \
        $(EFIDROID_COMMON_DIR)/lib/newkeys

    # enable the UEFIAPI
    DEFINES += WITH_KERNEL_UEFIAPI=1

    DEFINES += LCD_DENSITY=$(LCD_DENSITY)
    DEFINES += LCD_VRAM_SIZE=$(LCD_VRAM_SIZE)
    CFLAGS += -DDEVICE_NVVARS_PARTITION=\"$(DEVICE_NVVARS_PARTITION)\"

    # disable LK debugging
    DEBUG := 0

    # add libboot includes
    LIBBOOT_DIR := $(EFIDROID_TOP)/modules/libboot
    INCLUDES += -I$(LIBBOOT_DIR)/include
    INCLUDES += -I$(LIBBOOT_DIR)/include_private
    INCLUDES += -I$(EFIDROID_COMMON_DIR)/lib/boot/include
else
    DEFINES += WITH_DEBUG_LOG_BUF=1

    # enable FBCON
    DEFINES += WITH_DEBUG_FBCON=1

    # enable libboot
    MODULES += $(EFIDROID_COMMON_DIR)/lib/boot
    DEFINES += WITH_LIB_BOOT=1

    ifeq ($(EFIDROID_BUILD_TYPE),DEBUG)
        DEBUG := 3
        DEFINES += LK_LOG_BUF_SIZE=16384
    endif
endif

# optionally include device specific makefile
-include $(EFIDROID_DEVICE_DIR)/lk_inc.mk

# disable risky code and always force fastboot mode
DEFINES += EFIDROID_SAFEBOOT=1
