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

EDK2_BIN="$EDK2_OUT/Build/EFIDroid-${EDK2_ARCH}/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/FV/EFIDROID_EFI.fd"
FVMAIN_COMPACT_MAP="$EDK2_OUT/Build/EFIDroid-${EDK2_ARCH}/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/FV/FVMAIN_COMPACT.Fv.map"
LOCAL_MKBOOTIMG_ADDITIONAL_FLAGS="$BOOTIMG_ADDITIONAL_ARGS"

if [ ! -z "$BOOTIMG_DT" ];then
    LOCAL_MKBOOTIMG_ADDITIONAL_FLAGS="$LOCAL_MKBOOTIMG_ADDITIONAL_FLAGS --dt $BOOTIMG_DT"
fi

Configure() {
    # setup
    EDK2Setup

    # symlink device dir
    rm -f "$EDK2_OUT/EFIDroidDevicePkg"
    ln -s "$DEVICE_DIR" "$EDK2_OUT/EFIDroidDevicePkg"

    # symlink devices
    rm -f "$EDK2_OUT/EFIDroidDevices"
    ln -s "$TOP/device" "$EDK2_OUT/EFIDroidDevices"
}

Compile() {
    LOCAL_KERNEL="$EDK2_BIN"

    # compile
    CompileEDK2 "EFIDroidPkg/EFIDroidPkg.dsc" "$UEFI_VARIABLES_CMDLINE"

    # append FDT
    if [ ! -z "$BOOTIMG_APPENDED_FDT" ];then
        cp "$LOCAL_KERNEL" "$LOCAL_KERNEL.withfdt"
        cat "$BOOTIMG_APPENDED_FDT" >> "$LOCAL_KERNEL.withfdt"
        LOCAL_KERNEL="$LOCAL_KERNEL.withfdt"
    fi

    # generate meta data
    "$TOP/build/tools/create_efidroid_metadata" "$DEVICE" > "$DEVICE_OUT/efidroid_meta.bin"

    # generate boot images
    for part in $DEVICE_UEFI_PARTITIONS; do
        pr_alert "Installing: $DEVICE_OUT/uefi_$part.img"
        set -x
        "$TOP/build/tools/mkbootimg" \
            --kernel "$LOCAL_KERNEL" \
            --ramdisk /dev/null \
            --base "$BOOTIMG_BASE" \
            --cmdline "uefi.bootpart=$part" \
            $LOCAL_MKBOOTIMG_ADDITIONAL_FLAGS \
            -o "$DEVICE_OUT/uefi_$part.img"
        set +x
        cat "$DEVICE_OUT/efidroid_meta.bin" >> "$DEVICE_OUT/uefi_$part.img"
    done
}

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    Clean
}
