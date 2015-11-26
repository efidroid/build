UBOOT_DIR="$TOP/bootloader/uboot/common/master"
UBOOT_OUT="$MODULE_OUT"
UBOOT_ARGS="ARCH=arm CROSS_COMPILE=$GCC_EABI O=$UBOOT_OUT"

if [ ! -z "$UBOOT_SOURCE" ];then
    UBOOT_DIR="$TOP/bootloader/$UBOOT_SOURCE"
fi

Check() {
    if [ -z "$UBOOT_TARGET" ];then
        pr_fatal "UBOOT_TARGET is not set"
    fi
    if [ ! -d "$UBOOT_DIR" ];then
        pr_fatal "U-Boot wasn't found at $UBOOT_DIR"
    fi
}

Compile() {
    Check
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$UBOOT_DIR" $UBOOT_ARGS "$UBOOT_TARGET"
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$UBOOT_DIR" $UBOOT_ARGS all
}

Clean() {
    if [ ! -z "$UBOOT_TARGET" ];then
        Check
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$UBOOT_DIR" $UBOOT_ARGS clean
    fi
}

DistClean() {
    if [ ! -z "$UBOOT_TARGET" ];then
        Check
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$UBOOT_DIR" $UBOOT_ARGS distclean
    fi
}
