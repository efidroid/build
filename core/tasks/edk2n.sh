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
EDK2_DEFINES=""
EDK2_DEFINES="$EDK2_DEFINES -DEFIDROID_UEFIRD=Build/uefird.cpio"

Configure() {
    # setup
    EDK2Setup

    # symlink device dir
    rm -f "$EDK2_OUT/EFIDroidDevicePkg"
    ln -s "$DEVICE_DIR" "$EDK2_OUT/EFIDroidDevicePkg"

    # link apps
    mkdir -p "$EDK2_OUT/Build"
    rm -f "$EDK2_OUT/Build/uefiapp_EFIDroidUi"
    ln -s "$UEFIAPP_EFIDROIDUI_OUT/Build/EFIDroidUEFIApps" "$EDK2_OUT/Build/uefiapp_EFIDroidUi"

    # link uefird
    rm -f "$EDK2_OUT/Build/uefird.cpio"
    ln -s "$UEFIRD_CPIO" "$EDK2_OUT/Build/uefird.cpio"
}

Compile() {
    # compile
    CompileEDK2 "EFIDroidPkg/EFIDroidPkg.dsc" "$EDK2_DEFINES $UEFI_VARIABLES_CMDLINE"

    # generate meta data
    "$TOP/build/tools/create_efidroid_metadata" "$DEVICE" > "$DEVICE_OUT/efidroid_meta.bin"

    # generate boot images
    for part in $DEVICE_UEFI_PARTITIONS; do
        pr_alert "Installing: $DEVICE_OUT/uefi_$part.img"
        set -x
        "$TOP/build/tools/mkbootimg" \
            --kernel "$EDK2_BIN" \
            --ramdisk /dev/null \
            --base "$BOOTIMG_BASE" \
            --cmdline "uefi.bootpart=$part" \
            --dt "$BOOTIMG_DT" \
            $BOOTIMG_ADDITIONAL_ARGS \
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
