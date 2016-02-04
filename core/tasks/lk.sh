LK_DIR="$TOP/bootloader/lk/common/LA.BF64"
LK_OUT="$MODULE_OUT"
LK_ENV="BOOTLOADER_OUT=$LK_OUT ARCH=arm SUBARCH=arm TOOLCHAIN_PREFIX=$GCC_EABI"
# optionally overwrite MEMBASE
if [ -n "$LK_BASE" ];then
    LK_ENV="$LK_ENV MEMBASE=$LK_BASE"
fi
LK_ENV="$LK_ENV LK_EXTERNAL_MAKEFILE=$TOP/build/core/lk_inc.mk EFIDROID_TOP=$TOP"
LK_ENV="$LK_ENV EFIDROID_DEVICE_DIR=$TOP/device/$DEVICE"
LK_ENV="$LK_ENV EFIDROID_BUILD_TYPE=$BUILDTYPE"
LK_ENV_NOUEFI="$LK_ENV BOOTLOADER_OUT=$LK_OUT"

LK_ENV="$LK_ENV EDK2_BASE=$EDK2_BASE EDK2_API_INC=$TOP/uefi/edk2packages/LittleKernelPkg/Include"
LK_ENV="$LK_ENV WITH_KERNEL_UEFIAPI=1"
LK_ENV="$LK_ENV LCD_DENSITY=$LCD_DENSITY"
LK_ENV="$LK_ENV DEVICE_NVVARS_PARTITION=\"$DEVICE_NVVARS_PARTITION_LK\""

# check if lk source exists
if [ ! -z "$LK_SOURCE" ];then
    LK_DIR="$TOP/bootloader/$LK_SOURCE"
fi

# add (default) vram size
if [ -z "$LCD_VRAM_SIZE" ];then
    LCD_VRAM_SIZE="$((8*1024*1024))"
fi
LK_ENV="$LK_ENV LCD_VRAM_SIZE=$LCD_VRAM_SIZE"

# check required variables
if [ -z "$BOOTIMG_BASE" ];then
    pr_fatal "BOOTIMG_BASE is not set"
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

# device tree
if [ ! -z "$BOOTIMG_DT" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --dt $BOOTIMG_DT"
fi

# pagesize
if [ ! -z "$BOOTIMG_PAGESIZE" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --pagesize $BOOTIMG_PAGESIZE"
fi

# additional args
if [ ! -z "$BOOTIMG_ADDITIONAL_ARGS" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS $BOOTIMG_ADDITIONAL_ARGS"
fi

CompileLK() {
    mkdir -p "$LK_OUT"
    "$EFIDROID_SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
}

CompileLKEDK2() {
    C="$LK_OUT/tmp.c"
    BIN="$LK_OUT/tmp"
    LKEDK2BIN="$LK_OUT/build-$LK_TARGET/lk-edk2.bin"
    EDK2_SIZE="$(stat -L -c %s $EDK2_BIN)"

    # generate C file
    echo "#include <unistd.h>" > "$C"
    echo "int main(void){unsigned int n=$EDK2_SIZE;char c;" >> "$C"
    echo "c=(n>>(8*0))&0xff; write(1, &c, 1);" >> "$C"
    echo "c=(n>>(8*1))&0xff; write(1, &c, 1);" >> "$C"
    echo "c=(n>>(8*2))&0xff; write(1, &c, 1);" >> "$C"
    echo "c=(n>>(8*3))&0xff; write(1, &c, 1);" >> "$C"
    echo "return 0;" >> "$C"
    echo "}" >> "$C"

    # compile C file
    gcc -Wall -Wextra -Wshadow -Werror "$C" -o "$BIN"

    # write LK
    cp "$LK_OUT/build-$LK_TARGET/lk.bin" "$LKEDK2BIN"

    # write size
    "$BIN" >> "$LKEDK2BIN"

    # write EDK2
    cat "$EDK2_BIN" >> "$LKEDK2BIN"
}

CompileLKSideload() {
    pr_alert "Installing: $TARGET_OUT/lk_sideload.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk-edk2.bin" \
		--ramdisk /dev/null \
		--base "$BOOTIMG_BASE" \
		$LK_MKBOOTIMG_ADDITIONAL_FLAGS \
		-o "$TARGET_OUT/lk_sideload.img"
    set +x

    pr_alert "Installing: $TARGET_OUT/lk_sideload_recovery.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk-edk2.bin" \
		--ramdisk /dev/null \
		--base "$BOOTIMG_BASE" \
        --cmdline "uefi.bootmode=recovery" \
		$LK_MKBOOTIMG_ADDITIONAL_FLAGS \
		-o "$TARGET_OUT/lk_sideload_recovery.img"
    set +x
}

Clean() {
    "$EFIDROID_SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET clean"
}

DistClean() {
    rm -Rf $LK_OUT/*
}

CompileLKNoUEFI() {
    mkdir -p "$LK_OUT"
    "$EFIDROID_SHELL" -c "$LK_ENV_NOUEFI \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
}

CompileLKSideloadNoUEFI() {
    pr_alert "Installing: $TARGET_OUT/lk_nouefi_sideload.img"
    set -x
	"$HOST_MKBOOTIMG_OUT/mkbootimg" \
		--kernel "$LK_OUT/build-$LK_TARGET/lk.bin" \
		--ramdisk /dev/null \
		--base "$BOOTIMG_BASE" \
		$LK_MKBOOTIMG_ADDITIONAL_FLAGS \
		-o "$TARGET_OUT/lk_nouefi_sideload.img"
    set +x
}
