LK_DIR="$TOP/bootloader/lk/common/master"
LK_OUT="$MODULE_OUT"
LK_ENV="BOOTLOADER_OUT=$LK_OUT ARCH=arm SUBARCH=arm TOOLCHAIN_PREFIX=$GCC_EABI"
LK_ENV="$LK_ENV MEMBASE=$LK_BASE"
LK_ENV="$LK_ENV LK_EXTERNAL_MAKEFILE=$TOP/build/core/lk_inc.mk EFIDROID_TOP=$TOP"
LK_ENV="$LK_ENV EFIDROID_DEVICE_DIR=$TOP/device/$DEVICE"
LK_ENV_NOUEFI="$LK_ENV BOOTLOADER_OUT=$LK_OUT"

LK_ENV="$LK_ENV EDK2_SIZE=$(stat -L -c %s $EDK2_BIN)"
LK_ENV="$LK_ENV EDK2_BASE=$EDK2_BASE EDK2_API_INC=$TOP/uefi/edk2packages/LittleKernelPkg/Include"
LK_ENV="$LK_ENV WITH_KERNEL_UEFIAPI=1"
LK_ENV="$LK_ENV LCD_DENSITY=$LCD_DENSITY"
LK_ENV="$LK_ENV DEVICE_NVVARS_PARTITION=\"$DEVICE_NVVARS_PARTITION_LK\""

# check if lk source exists
if [ ! -z "$LK_SOURCE" ];then
    LK_DIR="$TOP/bootloader/$LK_SOURCE"
fi

# check required variables
if [ -z "$LK_BASE" ];then
    pr_fatal "LK_BASE is not set"
fi
if [ -z "$LK_TARGET" ];then
    pr_fatal "LK_TARGET is not set"
fi
if [ -z "$LCD_DENSITY" ];then
    pr_fatal "LCD_DENSITY is not set"
fi
if [ -z "$DEVICE_NVVARS_PARTITION_LK" ];then
    pr_fatal "DEVICE_NVVARS_PARTITION_LK is not set"
fi
if [ ! -d "$LK_DIR" ];then
    pr_fatal "LK wasn't found at $LK_DIR"
fi

# optional arguments
LK_MKBOOTIMG_ADDITIONAL_FLAGS=""

if [ ! -z "$LK_DT_IMG" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --dt $LK_DT_IMG"
fi

CompileLK() {
    mkdir -p "$LK_OUT"
    "$SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
    cat "$LK_OUT/build-$LK_TARGET/lk.bin" "$EDK2_BIN" >"$LK_OUT/build-$LK_TARGET/lk-edk2.bin"
}

CompileLKSideload() {
    pr_alert "Installing: $TARGET_OUT/lk_sideload.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk-edk2.bin" \
		--ramdisk /dev/null \
		--base $(printf "0x%x" $(($LK_BASE - 0x8000))) \
		$LK_MKBOOTIMG_ADDITIONAL_FLAGS \
		-o "$TARGET_OUT/lk_sideload.img"
    set +x

    pr_alert "Installing: $TARGET_OUT/lk_sideload_recovery.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk-edk2.bin" \
		--ramdisk /dev/null \
		--base $(printf "0x%x" $(($LK_BASE - 0x8000))) \
        --cmdline "uefi.bootmode=recovery" \
		$LK_MKBOOTIMG_ADDITIONAL_FLAGS \
		-o "$TARGET_OUT/lk_sideload_recovery.img"
    set +x
}

Clean() {
    "$SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET clean"
}

DistClean() {
    rm -Rf $LK_OUT/*
}

CompileLKNoUEFI() {
    mkdir -p "$LK_OUT"
    "$SHELL" -c "$LK_ENV_NOUEFI \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
}

CompileLKSideloadNoUEFI() {
    pr_alert "Installing: $TARGET_OUT/lk_nouefi_sideload.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk.bin" \
		--ramdisk /dev/null \
		--base $(printf "0x%x" $(($LK_BASE - 0x8000))) \
		-o "$TARGET_OUT/lk_nouefi_sideload.img"
    set +x
}
