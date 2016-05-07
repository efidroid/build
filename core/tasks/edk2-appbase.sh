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

setflag_printlevel "$DEBUG_INIT"
setflag_printlevel "$DEBUG_WARN"
setflag_printlevel "$DEBUG_LOAD"
setflag_printlevel "$DEBUG_FS"
#setflag_printlevel "$DEBUG_POOL"
#setflag_printlevel "$DEBUG_PAGE"
setflag_printlevel "$DEBUG_INFO"
setflag_printlevel "$DEBUG_DISPATCH"
setflag_printlevel "$DEBUG_VARIABLE"
setflag_printlevel "$DEBUG_BM"
setflag_printlevel "$DEBUG_BLKIO"
setflag_printlevel "$DEBUG_NET"
setflag_printlevel "$DEBUG_UNDI"
setflag_printlevel "$DEBUG_LOADFILE"
setflag_printlevel "$DEBUG_EVENT"
setflag_printlevel "$DEBUG_GCD"
setflag_printlevel "$DEBUG_CACHE"
setflag_printlevel "$DEBUG_VERBOSE"
setflag_printlevel "$DEBUG_ERROR"

setflag_propertymask "$DEBUG_PROPERTY_DEBUG_ASSERT_ENABLED"
setflag_propertymask "$DEBUG_PROPERTY_DEBUG_PRINT_ENABLED"
setflag_propertymask "$DEBUG_PROPERTY_DEBUG_CODE_ENABLED"
#setflag_propertymask "$DEBUG_PROPERTY_CLEAR_MEMORY_ENABLED"
setflag_propertymask "$DEBUG_PROPERTY_ASSERT_BREAKPOINT_ENABLED"
setflag_propertymask "$DEBUG_PROPERTY_ASSERT_DEADLOOP_ENABLED"

# set build type
if [ "$BUILDTYPE" == "DEBUG" ];then
    EDK2_BUILD_TYPE="DEBUG"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_ENABLE_OUTPUT=TRUE"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_PRINT_ERROR_LEVEL=$EDK2_PRINT_ERROR_LEVEL"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_PROPERTY_MASK=$EDK2_PROPERTY_MASK"
elif [ "$BUILDTYPE" == "USERDEBUG" ];then
    EDK2_BUILD_TYPE="RELEASE"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_ENABLE_OUTPUT=TRUE"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_PRINT_ERROR_LEVEL=$EDK2_PRINT_ERROR_LEVEL"
    EDK2_DEFINES="$EDK2_DEFINES -DDEBUG_PROPERTY_MASK=$EDK2_PROPERTY_MASK"
elif [ "$BUILDTYPE" == "RELEASE" ];then
    EDK2_BUILD_TYPE="RELEASE"
fi

Setup() {
    # setup build directory
    mkdir -p "$EDK2_OUT"
    "$TOP/build/tools/edk2_update" "$EDK2_DIR" "$EDK2_OUT"

    # symlink uefi/apps
    ln -s "$TOP/uefi/apps" "$EDK2_OUT/EFIDroidUEFIApps"

    # symlink modules
    ln -s "$TOP/modules" "$EDK2_OUT/EFIDroidModules"

    # (re)compile BaseTools
    MAKEFLAGS= "$EFIDROID_MAKE" -C "$EDK2_OUT/BaseTools"

    cp "$EDK2_OUT/BaseTools/Conf/tools_def.template" "$EDK2_OUT/Conf/tools_def.txt"
    sed -i "s/fstack-protector/fno-stack-protector/g" "$EDK2_OUT/Conf/tools_def.txt"
}

Compile() {
    # setup
    Setup

    # compile MdePkg
    CompileEDK2 "$MdePkg/MdePkg.dsc"
}

CompileApp() {
    # get app info
    APPNAME="${UEFIAPP##*/}"

    # setup
    Setup

    if [ ! -f "$EDK2_OUT/EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc" ];then
        APPCONFIG_REL="Conf/UEFIApp_$APPNAME.dsc"
        APPCONFIG="$EDK2_OUT/$APPCONFIG_REL"

        # build dsc file
        cp "$TOP/build/core/EFIDroidUEFIApps.dsc" "$APPCONFIG"
        sed -i "s/\[Components\]/\[Components\]\n  EFIDroidUEFIApps\/$APPNAME\/$APPNAME.inf/g" "$APPCONFIG"

        if [ -f "$EDK2_OUT/EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc.inc" ];then
            echo -e "\n!include EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc.inc" >> "$APPCONFIG"
        fi
    else
        APPCONFIG_REL="EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc"
    fi

    # compile
    CompileEDK2 "$APPCONFIG_REL" "$EDK2_DEFINES"

    # print binary path
    BASENAME=$(awk -F "=" '/BASE_NAME/ {print $2}' "$UEFIAPP/$APPNAME.inf" | tr -d '[[:space:]]')
    pr_alert "Installing: $EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"
}

Clean() {
    # get app info
    APPNAME="${UEFIAPP##*/}"
    BASENAME=$(awk -F "=" '/BASE_NAME/ {print $2}' "$UEFIAPP/$APPNAME.inf" | tr -d '[[:space:]]')
    EFIPATH="$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"

    # remove build files
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.debug"
    rm -Rf "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/EFIDroidUEFIApps/$BASENAME"
}

DistClean() {
    rm -Rf $EDK2_OUT/*
}
