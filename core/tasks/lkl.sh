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
LKL_SRC_PATCHED="$MODULE_OUT/src"
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
export LKL_INSTALL_ADDITIONAL_HEADERS="$MODULE_OUT/additional_headers.txt"

#
# generate additional_headers.txt
#
echo "" > "$LKL_INSTALL_ADDITIONAL_HEADERS"
# for LKLFS
echo "include/uapi/linux/dm-ioctl.h" >> "$LKL_INSTALL_ADDITIONAL_HEADERS"
# for LKLTS
echo "include/uapi/linux/input.h" >> "$LKL_INSTALL_ADDITIONAL_HEADERS"

FileHasChanged() {
    SRC="$1"
    DST="$2"
    MODTIME_SRC=$(stat -c %Y "$SRC")
    MODTIME_DST=$(stat -c %Y "$DST")

    #return 0
    if [ "$MODTIME_SRC" -gt "$MODTIME_DST" ];then
        return 0
    else
        return 1
    fi
}

LinkAll() {
    SRCDIR="$1"
    DSTDIR="$2"

    for f in "$SRCDIR/"*;do
        fname=${f##*/}
        targetpath="$DSTDIR/$fname"

        if [ ! -e "$targetpath" ];then
            # remove existing symlink
            if [ -L "$targetpath" ]; then
                rm "$targetpath"
            fi

            # create link if theres no file
            if [ ! -e "$targetpath" ];then
                ln -s "$f" "$targetpath"
            fi
        fi
    done
}

Compile() {
    MODTIME=0
    mkdir -p "$LKL_OUT"
    mkdir -p "$LKL_INSTALL"
    mkdir -p "$LKL_SRC_PATCHED"

    # create links
    LinkAll "$LKL_SRC" "$LKL_SRC_PATCHED"
    if [ -L "$LKL_SRC_PATCHED/drivers" ]; then
        rm "$LKL_SRC_PATCHED/drivers"
        mkdir "$LKL_SRC_PATCHED/drivers"
        LinkAll "$LKL_SRC/drivers" "$LKL_SRC_PATCHED/drivers"
    fi
    rm -f "$LKL_SRC_PATCHED/drivers/efidroid"
    ln -sf "$TOP" "$LKL_SRC_PATCHED/drivers/efidroid"


    # create list of Kconfigs and Makefiles
    kconfigs=""
    makefile_dirs=""
    kconfig_changed=0
    makefile_changed=0
    for d in $LKL_DRIVER_DIRECTORIES ;do
        # get absolute path
        if [ "${d:0:1}" != "/" ];then
            d="$TOP/$d"
        fi

        # check if dir exists
        if [ ! -d "$d" ];then
            continue;
        fi

        # get relative path
        drel=$(realpath --relative-to="$TOP" "$d")

        if [ -f "$d/Makefile" ];then
            makefile_dirs="$makefile_dirs $drel"

            if FileHasChanged "$d/Makefile" "$LKL_SRC_PATCHED/drivers/Makefile" ;then
                makefile_changed=1
            fi
        fi
        if [ -f "$d/Kconfig" ];then
            kconfigs="$kconfigs $drel/Kconfig"

            if FileHasChanged "$d/Kconfig" "$LKL_SRC_PATCHED/drivers/Kconfig" ;then
                kconfig_changed=1
            fi
        fi
    done

    # extend include path
    if [ -L "$LKL_SRC_PATCHED/Makefile" ] || FileHasChanged "$LKL_SRC/Makefile" "$LKL_SRC_PATCHED/Makefile";then
        pr_info "patch makefile"
        rm "$LKL_SRC_PATCHED/Makefile"
        cp "$LKL_SRC/Makefile" "$LKL_SRC_PATCHED/Makefile"

        APPEND_STR=""
        for f in $makefile_dirs ;do
            APPEND_STR="$APPEND_STR\n\t\t-I\$(srctree)/drivers/efidroid/$f/include \\\\"
        done

        sed -i "s/^LINUXINCLUDE\s*:\=\s*\\\\\$/\0${APPEND_STR//\//\\/}/g" "$LKL_SRC_PATCHED/Makefile"
    fi

    # include Kconfigs
    if [ -L "$LKL_SRC_PATCHED/drivers/Kconfig" ] || [ $kconfig_changed -eq 1 ];then
        pr_info "patch kconfig"
        rm "$LKL_SRC_PATCHED/drivers/Kconfig"
        cp "$LKL_SRC/drivers/Kconfig" "$LKL_SRC_PATCHED/drivers/Kconfig"

        for f in $kconfigs ;do
            echo "source \"drivers/efidroid/$f\"" >> "$LKL_SRC_PATCHED/drivers/Kconfig"
        done
    fi

    # include Makefiles
    if [ -L "$LKL_SRC_PATCHED/drivers/Makefile" ] || [ $makefile_changed -eq 1 ];then
        pr_info "patch makefile"
        rm "$LKL_SRC_PATCHED/drivers/Makefile"
        cp "$LKL_SRC/drivers/Makefile" "$LKL_SRC_PATCHED/drivers/Makefile"

        for f in $makefile_dirs ;do
            echo "obj-y += efidroid/$f/" >> "$LKL_SRC_PATCHED/drivers/Makefile"
        done
    fi

    # check if any defconfig has changed
    rebuild_cfg=0
    if [ -f "$LKL_OUT/.config" ];then
        if FileHasChanged "$LKL_SRC/arch/lkl/defconfig" "$LKL_OUT/.config";then
            rebuild_cfg=1
        fi
        if FileHasChanged "$TOP/build/core/tasks/efidroid_defconfig" "$LKL_OUT/.config";then
            rebuild_cfg=1
        fi
        if [ "$LKL_CONFIG_OVERLAY" != "" ] && FileHasChanged "$LKL_CONFIG_OVERLAY" "$LKL_OUT/.config";then
            rebuild_cfg=1
        fi
    fi

    # rebuild .config
    if [ ! -f "$LKL_OUT/.config" ] || [ $rebuild_cfg -eq 1 ]; then
        pushd "$LKL_SRC_PATCHED"
        KCONFIG_CONFIG="$LKL_OUT/.config" "scripts/kconfig/merge_config.sh" "arch/lkl/defconfig" "$TOP/build/core/tasks/efidroid_defconfig" "$LKL_CONFIG_OVERLAY"
        popd
    fi

    # get modification time
    if [ -f "$LKL_OUT/lkl.o" ];then
        MODTIME=$(stat -c %Y "$LKL_INSTALL/lib/lkl.o")
    fi

    # compile lkl.o
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC_PATCHED"

    # check if the lib was modified
    MODTIME_NEW=$(stat -c %Y "$LKL_OUT/lkl.o")
    if [ "$MODTIME_NEW" -gt "$MODTIME" ];then
        # install headers
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC_PATCHED" install
        cp "$LKL_SRC_PATCHED/tools/lkl/include/lkl.h" "$LKL_INSTALL/include"
        cp "$LKL_SRC_PATCHED/tools/lkl/include/lkl_host.h" "$LKL_INSTALL/include"

        # copy lib for UEFI
        cp $LKL_INSTALL/lib/lkl.o $LKL_INSTALL/lib/lkl.prebuilt
    fi
}

########################################
#              CLEANUP                 #
########################################

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$LKL_SRC_PATCHED" clean
}

DistClean() {
    rm -Rf $MODULE_OUT/*
}
