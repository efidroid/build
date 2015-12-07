Compile() {
    qemu-arm "$HOST_GRUB_KERNEL_OUT/grub-mkimage" \
        -O arm-efi \
        -c "$GRUB_CONFIG_DIR/load.cfg" \
        -o "$MODULE_OUT/grub.efi" \
        -d "$HOST_GRUB_KERNEL_OUT/grub-core" \
        -p "" \
        $(cd $HOST_GRUB_KERNEL_OUT/grub-core && find *.mod | xargs -I {} basename {} .mod | xargs)
}

Clean() {
    rm -f "$MODULE_OUT/grub.efi"
}

DistClean() {
    Clean
}
