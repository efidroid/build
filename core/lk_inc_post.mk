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

ifeq ($(WITH_KERNEL_UEFIAPI),1)
    # remove all apps
    MODULES := $(filter-out app/aboot,$(MODULES))
    MODULES := $(filter-out app/clocktests,$(MODULES))
    MODULES := $(filter-out app/nandwrite,$(MODULES))
    MODULES := $(filter-out app/pcitests,$(MODULES))
    MODULES := $(filter-out app/rpmbtests,$(MODULES))
    MODULES := $(filter-out app/shell,$(MODULES))
    MODULES := $(filter-out app/stringtests,$(MODULES))
    MODULES := $(filter-out app/tests,$(MODULES))

    # remove exception related arch objects
    OBJS := $(filter-out arch/arm/exceptions.o,$(OBJS))
    OBJS := $(filter-out arch/arm/mmu.o,$(OBJS))
    OBJS := $(filter-out arch/arm/mmu_lpae.o,$(OBJS))
    OBJS := $(filter-out arch/arm/thread.o,$(OBJS))

    # remove threading related kernel objects
    OBJS := $(filter-out kernel/event.o,$(OBJS))
    OBJS := $(filter-out kernel/main.o,$(OBJS))
    OBJS := $(filter-out kernel/mutex.o,$(OBJS))
    OBJS := $(filter-out kernel/thread.o,$(OBJS))
    OBJS := $(filter-out kernel/timer.o,$(OBJS))
    OBJS := $(filter-out app/app.o,$(OBJS))

    # this uses timers which aren't available in UEFI
    DEFINES := $(filter-out LONG_PRESS_POWER_ON=1,$(DEFINES))

    # disable stack protector
    CFLAGS := $(filter-out -fstack-protector-all,$(CFLAGS))
endif

# optionally include device specific makefile
-include $(EFIDROID_DEVICE_DIR)/lk_inc_post.mk

# disable target display driver
ifeq ($(DISPLAY_2NDSTAGE),1)
    OBJS := $(filter-out target/$(TARGET)/target_display.o,$(OBJS))
endif

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

ifneq ($(PERSISTENT_RAM_ADDR),)
    CFLAGS += -DPERSISTENT_RAM_ADDR=$(PERSISTENT_RAM_ADDR)
endif

ifneq ($(PERSISTENT_RAM_SIZE),)
    CFLAGS += -DPERSISTENT_RAM_SIZE=$(PERSISTENT_RAM_SIZE)
endif

ifeq ($(WITH_DEBUG_LAST_KMSG),1)
    CFLAGS += -DWITH_DEBUG_LAST_KMSG=1
endif

ifeq ($(WITH_KERNEL_UEFIAPI),1)
    ifeq ($(DEBUG_ENABLE_UEFI_FBCON),1)
        # enable FBCON
        DEFINES += WITH_DEBUG_FBCON=1

        CFLAGS += -DDEBUG_ENABLE_UEFI_FBCON=1
    else
        CFLAGS += -DDEBUG_ENABLE_UEFI_FBCON=0
    endif
endif
