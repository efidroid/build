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

source "$TOP/build/core/tasks/edk2-common.sh"

# set build type
if [ "$BUILDTYPE" == "DEBUG" ];then
    EDK2_BUILD_TYPE="DEBUG"
elif [ "$BUILDTYPE" == "USERDEBUG" ];then
    EDK2_BUILD_TYPE="RELEASE"
elif [ "$BUILDTYPE" == "RELEASE" ];then
    EDK2_BUILD_TYPE="RELEASE"
fi

# check required variables
if [ -z "$EDK2_BASE" ];then
    pr_fatal "EDK2_BASE is not set"
fi

# default values
if [ -z "$DRAM_BASE" ];then
    DRAM_BASE="$EDK2_BASE"
fi
if [ -z "$DRAM_SIZE" ];then
    DRAM_SIZE="0x01000000" # 16MB
fi

EDK2_BIN="$EDK2_OUT/Build/LittleKernelPkg/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/FV/FVMAIN_COMPACT.Fv"
EDK2_EFIDROID_OUT="$EDK2_OUT/Build/EFIDROID"
EDK2_FDF_INC="$EDK2_EFIDROID_OUT/LittleKernelPkg.fdf.inc"
EDK2_DEFINES="$EDK2_DEFINES -DFIRMWARE_VER=\"EFIDroid $EDK2_VERSION\""
EDK2_DEFINES="$EDK2_DEFINES -DDRAM_BASE=$DRAM_BASE"
EDK2_DEFINES="$EDK2_DEFINES -DDRAM_SIZE=$DRAM_SIZE"

# set global variables
setvar "EDK2_BIN" "$EDK2_BIN"
setvar "EDK2_BASE" "$EDK2_BASE"

Configure() {
    # setup
    EDK2Setup

    # link apps
    mkdir -p "$EDK2_EFIDROID_OUT"
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps"
    ln -s "$TARGET_COMMON_OUT/uefiapp_EFIDroidUi/Build/EFIDroidUEFIApps" "$EDK2_OUT/Build/EFIDroidUEFIApps"

    # generate FDF include file
    echo -e "DEFINE FD_BASE = $EDK2_BASE\n" >  "$EDK2_FDF_INC"
    echo -e "DEFINE FD_SIZE = 0x00400000\n" >> "$EDK2_FDF_INC"
    echo -e "DEFINE EFIDROID_UEFIRD        = Build/EFIDROID/uefird.cpio\n" >> "$EDK2_FDF_INC"

    # get EDK git revision
    tmp=$(cd "$EDK2_DIR" && git rev-parse --verify --short HEAD)
    setvar "EDK2_VERSION" "$tmp"
}

Compile() {
    # copy required files to workspace
    cp "$UEFIRD_CPIO" "$EDK2_EFIDROID_OUT/uefird.cpio"

    # compile
    CompileEDK2 "LittleKernelPkg/LittleKernelPkg.dsc" "$EDK2_DEFINES"
}

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    Clean
}
