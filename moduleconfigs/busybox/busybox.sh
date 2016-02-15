BB_ARGS="ARCH=arm CROSS_COMPILE=$GCC_LINUX_TARGET_PREFIX O=$MODULE_OUT"

EnableConfig() {
    sed -i "s/# $1 is not set/$1=y/g" "$MODULE_OUT/.config"
}

DisableConfig() {
    sed -i "s/$1=y/# $1 is not set/g" "$MODULE_OUT/.config"
}

Compile() {
    if [ ! -f "$MODULE_OUT/.config" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS allnoconfig
        EnableConfig CONFIG_STATIC
        EnableConfig CONFIG_SED
        EnableConfig CONFIG_LOSETUP
        EnableConfig CONFIG_DD
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_ASH
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_RM
        DisableConfig CONFIG_FEATURE_SH_IS_NONE
        EnableConfig CONFIG_FEATURE_SH_IS_ASH
        EnableConfig CONFIG_LFS
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS silentoldconfig
    fi

    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS all
}

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS clean
}

DistClean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS distclean
}
