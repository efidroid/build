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

inch2px() {
    INCH="$1"
    PIXEL=$(bc -l <<< "$INCH*$LCD_DENSITY" | awk '{print int($1+0.5)}')

    if [ "$(($PIXEL%2))" = 1 ]; then
	    PIXEL=$(($PIXEL+1))
    fi

    echo $PIXEL
    return 0
}

Compile() {
    # cleanup
    rm -f "$MODULE_OUT/grub.efi"
    rm -Rf "$MODULE_OUT/grubrd"
    rm -f "$MODULE_OUT/grubboot.img"

    qemu-arm "$TARGET_GRUB_KERNEL_OUT/grub-mkimage" \
        -O arm-efi \
        -c "$GRUB_CONFIG_DIR/load.cfg" \
        -o "$MODULE_OUT/grub.efi" \
        -d "$TARGET_GRUB_KERNEL_OUT/grub-core" \
        -p "" \
        $(cd $TARGET_GRUB_KERNEL_OUT/grub-core && find *.mod | xargs -I {} basename {} .mod | xargs)

    # directories
    mkdir "$MODULE_OUT/grubrd"
    mkdir "$MODULE_OUT/grubrd/fonts"
    mkdir "$MODULE_OUT/grubrd/locale"
    mkdir "$MODULE_OUT/grubrd/arm-efi"

    # font
    grub-mkfont -s $(inch2px "0.11") -o "$MODULE_OUT/unicode_uncompressed.pf2" "$GRUB_CONFIG_DIR/unifont.ttf"
    cat "$MODULE_OUT/unicode_uncompressed.pf2" | gzip >"$MODULE_OUT/grubrd/fonts/unicode.pf2"

    # env
    qemu-arm "$TARGET_GRUB_KERNEL_OUT/grub-editenv" "$MODULE_OUT/grubrd/grubenv" create

    # config
    cp "$GRUB_CONFIG_DIR/grub.cfg" "$MODULE_OUT/grubrd/grub.cfg"

    # all modules are builtin

    # boot.img
    mkefibootimg --efi "$MODULE_OUT/grub.efi" --dir "$MODULE_OUT/grubrd" "$MODULE_OUT/grubboot.img"
}

Clean() {
    rm -f "$MODULE_OUT/grub.efi"
}

DistClean() {
    Clean
}
