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

LKL_SRC="$TOP/uefi/lkl"
LKL_OUT="$MODULE_OUT/out"
LKL_INSTALL="$MODULE_OUT/install"

# ARM
if [ "$MODULE_ARCH" == "arm" ];then
    LKL_CFLAGS="$LKL_CFLAGS -mlittle-endian -mabi=aapcs -march=armv7-a -mthumb -mfloat-abi=soft -mword-relocations -fno-short-enums"
elif [ "$MODULE_ARCH" == "x86_64" ];then
    LKL_CFLAGS="$LKL_CFLAGS -mno-red-zone -mno-stack-arg-probe -m64 -maccumulate-outgoing-args -mcmodel=small -fpie -fno-asynchronous-unwind-tables"
fi

LKL_CFLAGS="$LKL_CFLAGS -ffunction-sections -fdata-sections -fno-PIC -fshort-wchar"

export ARCH="lkl"
export KBUILD_OUTPUT="$LKL_OUT"
export INSTALL_PATH="$LKL_INSTALL"
export KCFLAGS="$LKL_CFLAGS"
export CROSS_COMPILE="$GCC_NONE_TARGET_PREFIX"

EnableConfig() {
    sed -i "s/# $1 is not set/$1=y/g" "$LKL_OUT/.config"
}

DisableConfig() {
    sed -i "s/$1=y/# $1 is not set/g" "$LKL_OUT/.config"
}

AddYesConfig() {
    echo "$1=y" >> "$LKL_OUT/.config"
}
AddNoConfig() {
    echo "# $1 is not set" >> "$LKL_OUT/.config"
}

Compile() {
    MODTIME=0
    mkdir -p "$LKL_OUT"
    mkdir -p "$LKL_INSTALL"

    if [ ! -f "$LKL_OUT/.config" ];then
        # create default config
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC" defconfig

        # disable unused function
        DisableConfig CONFIG_KALLSYMS
        DisableConfig CONFIG_NET
        DisableConfig CONFIG_BTRFS_FS
        DisableConfig CONFIG_XFS_FS
        DisableConfig CONFIG_FAT_FS
        DisableConfig CONFIG_VFAT_FS
        DisableConfig CONFIG_PROC_FS
        DisableConfig CONFIG_KERNFS
        DisableConfig CONFIG_MISC_FILESYSTEMS
        DisableConfig CONFIG_HID
        DisableConfig CONFIG_USB_SUPPORT
        DisableConfig CONFIG_DEVMEM
        DisableConfig CONFIG_DEVKMEM
        DisableConfig CONFIG_INPUT

        # optimizations
        DisableConfig CONFIG_FRAME_POINTER
        EnableConfig CONFIG_CC_OPTIMIZE_FOR_SIZE

        # F2FS
        EnableConfig CONFIG_F2FS_FS
        AddYesConfig CONFIG_F2FS_FS_XATTR
        AddYesConfig CONFIG_F2FS_FS_POSIX_ACL
        AddYesConfig CONFIG_F2FS_FS_SECURITY
        AddNoConfig CONFIG_F2FS_CHECK_FS
        AddNoConfig CONFIG_F2FS_FS_ENCRYPTION
        AddNoConfig CONFIG_F2FS_FAULT_INJECTION

        # NTFS
        EnableConfig CONFIG_NTFS_FS
        AddNoConfig CONFIG_NTFS_DEBUG
        AddYesConfig CONFIG_NTFS_RW

        # dmcrypt
        EnableConfig CONFIG_MD
        AddYesConfig CONFIG_BLK_DEV_DM
        AddYesConfig CONFIG_DM_CRYPT
        AddYesConfig CONFIG_DM_VERITY

        # update config
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC" olddefconfig
    fi

    # get modification time
    if [ -f "$LKL_OUT/lkl.o" ];then
        MODTIME=$(stat -c %Y "$LKL_INSTALL/lib/lkl.o")
    fi

    # compile lkl.o
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC"

    # check if the lib was modified
    MODTIME_NEW=$(stat -c %Y "$LKL_OUT/lkl.o")
    if [ "$MODTIME_NEW" -gt "$MODTIME" ];then
        # install headers
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC" install
        cp "$LKL_SRC/tools/lkl/include/lkl.h" "$LKL_INSTALL/include"
        cp "$LKL_SRC/tools/lkl/include/lkl_host.h" "$LKL_INSTALL/include"

        # copy lib for UEFI
        cp $LKL_INSTALL/lib/lkl.o $LKL_INSTALL/lib/lkl.prebuilt
    fi
}

########################################
#              CLEANUP                 #
########################################

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC" clean
}

DistClean() {
    rm -Rf $MODULE_OUT/*
}
