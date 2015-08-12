ifneq ($(BUILD_WITH_COLORS),0)
    CL_RED="\033[1;31m"
    CL_GRN="\033[1;32m"
    CL_YLW="\033[1;33m"
    CL_BLU="\033[1;34m"
    CL_MAG="\033[1;35m"
    CL_CYN="\033[1;36m"
    CL_RST="\033[0m"
endif

# enable GCC colors by default (if supported)
export GCC_COLORS ?= 1

# Utility variables.
empty :=
space := $(empty) $(empty)
comma := ,
# Note that make will eat the newline just before endef.
define newline


endef
# Unfortunately you can't simply define backslash as \ or \\.
backslash := \a
backslash := $(patsubst %a,%,$(backslash))

# log functions
# logi(message)
define logi
    $(info $(shell echo -e ${CL_CYN}$(1)${CL_RST}))
endef
# logw(message)
define logw
    $(info $(shell echo -e ${CL_YLW}$(1)${CL_RST}))
endef
# loge(message)
define loge
    $(info $(shell echo -e ${CL_RED}))
    $(error $(shell echo -e "$(1)"${CL_RST}))
endef
# logv(message)
define logv
    $(info $(shell echo -e $(1)))
endef

# Only use EFIDROID_BUILD_SHELL to wrap around bash.
# DO NOT use other shells such as zsh.
ifdef EFIDROID_BUILD_SHELL
    SHELL := $(EFIDROID_BUILD_SHELL)
else
    # Use bash, not whatever shell somebody has installed as /bin/sh
    # This is repeated in config.mk, since envsetup.sh runs that file
    # directly.
    SHELL := /bin/bash
endif

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

# Check for broken versions of make.
# (Allow any version under Cygwin since we don't actually build the platform there.)
ifeq (,$(findstring CYGWIN,$(shell uname -sm)))
    ifneq (1,$(strip $(shell expr $(MAKE_VERSION) \>= 3.81)))
        $(warning ********************************************************************************)
        $(warning *  You are using version $(MAKE_VERSION) of make.)
        $(warning *  EFIDroid can only be built by versions 3.81 and higher.)
        $(warning ********************************************************************************)
        $(error stopping)
    endif
endif

# identify host kernel
KERNEL_NAME := $(shell uname -s)
ifeq ($(KERNEL_NAME),Linux)
    HOSTTYPE := linux-x86
endif
ifeq ($(KERNEL_NAME),Darwin)
    HOSTTYPE := darwin-x86
endif
ifeq ($(HOSTTYPE),)
    $(call loge,Unsupprted host kernel $(KERNEL_NAME))
endif

# clean macro
CLEANSTEPS =
# add-clean-step(target)
define add-clean-step
    $(eval CLEANSTEPS += $(1))
endef

# distclean macro
DISTCLEANSTEPS =
# add-distclean-step(target)
define add-distclean-step
    $(eval DISTCLEANSTEPS += $(1))
endef


# Absolute path of the present working direcotry.
# This overrides the shell variable $PWD, which does not necessarily points to
# the top of the source tree, for example when "make -C" is used in m/mm/mmm.
PWD := $(shell pwd)

TOP := .
TOPDIR :=

BUILD_SYSTEM := $(TOPDIR)build/core
OUT := $(TOPDIR)out
HOST_OUT := $(OUT)/host

# GCC
GCC_DIR := $(PWD)/$(TOPDIR)prebuilts/gcc/$(HOSTTYPE)
GCC_TARGET_DIR := $(GCC_DIR)/arm
GCC_LINUX_GNUEABI := $(GCC_TARGET_DIR)/arm-linux-gnueabihf-4.9/bin/arm-linux-gnueabihf-
GCC_EABI := $(GCC_TARGET_DIR)/arm-eabi-4.8/bin/arm-eabi-

# This is the default target.  It must be the first declared target.
.PHONY: all
DEFAULT_GOAL := all
$(DEFAULT_GOAL):

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

# Hi :)
$(call logi,EFIDroid Build System)

# These goals don't need to be built
nobuild_goals := \
    help out \
    show_devices

ifneq ($(filter $(nobuild_goals), $(MAKECMDGOALS)),)

    .PHONY: show_devices
    show_devices:
	    @echo Devices:
	    @for f in $(strip $(wildcard $(TOPDIR)device/*/*/config.mk)); do \
	        parts=($${f//\// });\
	        echo -e \\t$${parts[1]}/$${parts[2]}; \
	    done

    .PHONY: help
    help:
	    @echo
	    @echo "Common make targets:"
	    @echo "----------------------------------------------------------------------------------"
	    @echo "all                     Default target"
	    @echo "clean                   run 'make clean' on all targets"
	    @echo "distclean               equivalent to rm -rf out/"
	    @echo "help                    You're reading it right now"


    .PHONY: out
    out:
	    @echo "I'm sure you're nice and all, but no thanks."

else

    # add_cmake_target(type, outdir, sourcedir)
    define add_cmake_target
    $(strip \
        $(eval name := $(lastword $(subst /, ,$(3))))
        $(eval target := $(1)_$(name))

        $(eval cmakeargs := )
        $(if $(filter $(1),target), \
            $(eval cmakeargs := -DCMAKE_C_COMPILER=$(PWD)/$(GCC_LINUX_GNUEABI)gcc) \
            $(eval cmakeargs += -DCMAKE_CXX_COMPILER=$(PWD)/$(GCC_LINUX_GNUEABI)g++) \
        )

        $(eval .PHONY: $(target))
        $(eval $(target):
			@$${call logi,Compiling $(1)/$(name) ...}
			@mkdir -p $(2)/$(name)
			@cd $(2)/$(name) && cmake $(cmakeargs) $(PWD)/$(TOPDIR)external/$(1)/$(name) && $$(MAKE)
        )
    )
    endef

    # load_task(path)
    define load_task
    $(strip \
        $(eval include $(1))
    )
    endef

    # create main build dir
    $(shell mkdir -p ${OUT})
    # create host build dir
    $(shell mkdir -p ${HOST_OUT})

    # define host targets
    $(foreach p,$(wildcard $(TOPDIR)external/host/*),$(call add_cmake_target,host,$(HOST_OUT),$(p)))

    # check if device is set
    ifneq ($(DEVICEID),)

        # check if device config exists
        DEVICE_CONFIG = $(wildcard device/$(DEVICEID)/config.mk)
        ifeq ("","$(DEVICE_CONFIG)")
            $(call loge,device $(DEVICEID) doesn't exist)
        endif

        # include device config
        include $(DEVICE_CONFIG)

        # validate config
        ifeq ($(DEVICE_NAME),)
            $(call loge,DEVICE_NAME is not set)
        endif

        # extract vendor and device names
        VENDOR := $(shell (tmp=${DEVICEID};tmp=($${tmp//\// });echo $${tmp[0]}))
        DEVICE := $(shell (tmp=${DEVICEID};tmp=($${tmp//\// });echo $${tmp[1]}))
        TARGET_OUT := $(OUT)/target/product/$(DEVICE)

        $(call logi,Building for ${DEVICE_NAME} \(${VENDOR}/${DEVICE}\))

        # create target build dir
        $(shell mkdir -p ${TARGET_OUT})

        # define device targets
        $(foreach p,$(wildcard $(TOPDIR)external/target/*),$(call add_cmake_target,target,$(TARGET_OUT),$(p)))

        # include EDK2 first
        include $(BUILD_SYSTEM)/tasks/edk2.mk

        # load all other tasks
        $(foreach p,$(filter-out $(BUILD_SYSTEM)/tasks/edk2.mk,$(wildcard $(BUILD_SYSTEM)/tasks/*.mk)),$(call load_task,$(p)))

    else
        $(call logi,Building in host-only mode)
    endif

    .PHONY: clean
    clean: $(CLEANSTEPS)

    .PHONY: distclean
    distclean: $(DISTCLEANSTEPS)
		rm -Rf $(OUT)

endif # nobuild_goals
