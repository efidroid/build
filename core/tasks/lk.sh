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

LK_DIR=""
LK_OUT="$MODULE_OUT"
LK_ENV="BOOTLOADER_OUT=$LK_OUT ARCH=arm SUBARCH=arm TOOLCHAIN_PREFIX=$GCC_NONE_TARGET_PREFIX"
# optionally overwrite MEMBASE
if [ -n "$LK_BASE" ];then
    LK_ENV="$LK_ENV MEMBASE=$LK_BASE"
fi
LK_ENV="$LK_ENV LK_EXTERNAL_MAKEFILE=$TOP/build/core/lk_inc.mk EFIDROID_TOP=$TOP"
LK_ENV="$LK_ENV LK_EXTERNAL_MAKEFILE_POSTRULES=$TOP/build/core/lk_inc_post.mk"
LK_ENV="$LK_ENV EFIDROID_DEVICE_DIR=$TOP/device/$DEVICE"
LK_ENV="$LK_ENV EFIDROID_BUILD_TYPE=$BUILDTYPE"
LK_ENV="$LK_ENV DEVICE_DEFAULT_FDT_PARSER=\"$BOOTIMG_FDT_PARSER\""
LK_ENV_NOUEFI="$LK_ENV BOOTLOADER_OUT=$LK_OUT"

LK_ENV="$LK_ENV EDK2_API_INC=$TOP/uefi/edk2packages/LittleKernelPkg/Include"
LK_ENV="$LK_ENV WITH_KERNEL_UEFIAPI=1"
LK_ENV="$LK_ENV LCD_DENSITY=$LCD_DENSITY"
LK_ENV="$LK_ENV DEVICE_NVVARS_PARTITION=\"$DEVICE_NVVARS_PARTITION_LK\""

# check if lk source exists
if [ ! -z "$LK_SOURCE" ];then
    LK_DIR="$TOP/bootloader/lk/$LK_SOURCE"
else
    pr_fatal "LK_SOURCE is not set"
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

LK_BINARY="$LK_OUT/build-$LK_TARGET/lk.bin"
LK_BINARY_FINAL="$LK_OUT/lk_final.bin"
LK_BINARY_FINAL_ORIGDTB="$LK_OUT/lk_final_origdtb.bin"

# optional arguments
LK_MKBOOTIMG_ADDITIONAL_FLAGS=""
LK_MKBOOTIMG_ADDITIONAL_FLAGS_ORIGDTB=""

# DTB variables
DTBEFIDROIDIFY="$HOST_DTBTOOLS_OUT/dtbefidroidify"
QCDTEXTRACT="$HOST_DTBTOOLS_OUT/qcdtextract"
FDTEXTRACT="$HOST_DTBTOOLS_OUT/fdtextract"
DTBTOOL="$HOST_DTBTOOLS_OUT/dtbtool"
DTBDIR="$LK_OUT/dtb_out"
FDTDIR="$LK_OUT/fdt_out"
DTBPATCHEDDIR="$LK_OUT/dtbpatched_out"
FDTPATCHEDDIR="$LK_OUT/fdtpatched_out"
DTIMG_PATCHED="$LK_OUT/dt_patched.img"
FDT_PATCHED="$LK_OUT/fdt_patched.img"

# pagesize
if [ ! -z "$BOOTIMG_PAGESIZE" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --pagesize $BOOTIMG_PAGESIZE"
fi

# additional args
if [ ! -z "$BOOTIMG_ADDITIONAL_ARGS" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS $BOOTIMG_ADDITIONAL_ARGS"
fi

# device tree
if [ ! -z "$BOOTIMG_DT" ];then
    LK_MKBOOTIMG_ADDITIONAL_FLAGS_ORIGDTB="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --dt $BOOTIMG_DT"
    LK_MKBOOTIMG_ADDITIONAL_FLAGS="$LK_MKBOOTIMG_ADDITIONAL_FLAGS --dt $DTIMG_PATCHED"
else
    LK_MKBOOTIMG_ADDITIONAL_FLAGS_ORIGDTB="$LK_MKBOOTIMG_ADDITIONAL_FLAGS"
fi

DTBEFIDROIDIFY_REMOVE_NODES="1"
if [ "$BOOTIMG_DT_KEEP_NODES" == "1" ];then
    DTBEFIDROIDIFY_REMOVE_NODES="0"
fi

DTBEFIDROIDIFY_FDT_PARSER="$BOOTIMG_FDT_PARSER"
if [ "$DTBEFIDROIDIFY_FDT_PARSER" == "" ];then
    DTBEFIDROIDIFY_FDT_PARSER="qcom"
fi

DTBEFIDROIDIFY_QCDT_PARSER="$BOOTIMG_QCDT_PARSER"
if [ "$DTBEFIDROIDIFY_QCDT_PARSER" == "" ];then
    DTBEFIDROIDIFY_QCDT_PARSER="qcom"
fi


########################################
#               COMMON                 #
########################################

# the stock bootloader needs this to retreive the appended FDT offset
GenerateKernelHeader() {
    C="$LK_OUT/tmp.c"
    BIN="$LK_OUT/tmp"
    KERNEL_SIZE="$1"
    HEADER_OUT="$2"

    # generate C file
    echo "#include <unistd.h>" > "$C"
    echo "#include <stdint.h>" >> "$C"
    echo "int main(void){int i;uint32_t n;" >> "$C"
    echo "n=0xea00000a; write(1, &n, sizeof(n));" >> "$C"   # b 0x30
    echo "for(i=0;i<8;i++)" >> "$C"
    echo "{n=0xe1a00000; write(1, &n, sizeof(n));}" >> "$C" # NOP
    echo "n=0x016f2818; write(1, &n, sizeof(n));" >> "$C"   # Magic numbers to help the loader
    echo "n=0x00000000; write(1, &n, sizeof(n));" >> "$C"   # absolute load/run zImage address
    echo "n=$KERNEL_SIZE; write(1, &n, sizeof(n));" >> "$C" # zImage end address
    echo "return 0;" >> "$C"
    echo "}" >> "$C"

    # compile C file
    gcc -Wall -Wextra -Wshadow -Werror "$C" -o "$BIN"

    # write header
    "$BIN" >> "$HEADER_OUT"
}

NeedsRecompile() {
    SOURCEFILE="$1"
    COMPILEDFILE="$2"

    RECOMPILE=0
    if [ -f "$COMPILEDFILE" ] && [ -f "${COMPILEDFILE}.modtime" ];then
        MODTIME_SOURCE=$(stat -c %Y "$SOURCEFILE")
        MODTIME_BIN=$(cat "${COMPILEDFILE}.modtime")

        if [ "$MODTIME_SOURCE" -gt "$MODTIME_BIN" ];then
            RECOMPILE=1
            rm "${COMPILEDFILE}.modtime"
        fi
    else
        RECOMPILE=1
    fi

    echo $RECOMPILE
}

CreateModTimeFile() {
    SOURCEFILE="$1"
    COMPILEDFILE="$2"

    MODTIME=$(stat -c %Y "$SOURCEFILE")

    echo -n "$MODTIME" > "${COMPILEDFILE}.modtime"
}

# pre-parse and minify devicetree
GeneratePatchedDeviceTree() {
    if [ ! -z "$BOOTIMG_DT" ]; then
        RECOMPILE=$(NeedsRecompile "$BOOTIMG_DT" "$DTIMG_PATCHED")
        if [ "$RECOMPILE" -eq "1" ];then
            # cleanup
            rm -Rf "$DTBDIR"
            mkdir -p "$DTBDIR"
            rm -Rf "$DTBPATCHEDDIR"
            mkdir -p "$DTBPATCHEDDIR"

            # extract QCDT
            "$QCDTEXTRACT" "$BOOTIMG_DT" "$DTBDIR"

            # generate patched dtb's
            echo "$DTBEFIDROIDIFY" "$DTBDIR" "$DTBPATCHEDDIR" "$DTBEFIDROIDIFY_REMOVE_NODES" "$DTBEFIDROIDIFY_QCDT_PARSER"
            "$DTBEFIDROIDIFY" "$DTBDIR" "$DTBPATCHEDDIR" "$DTBEFIDROIDIFY_REMOVE_NODES" "$DTBEFIDROIDIFY_QCDT_PARSER"

            # generate new dt.img
            eval "\"$DTBTOOL\" $BOARD_DTBTOOL_ARGS -o \"$DTIMG_PATCHED\" \"$DTBPATCHEDDIR/\""

            CreateModTimeFile "$BOOTIMG_DT" "$DTIMG_PATCHED"
        fi
    fi

    if [ ! -z "$BOOTIMG_APPENDED_FDT" ]; then
        RECOMPILE=$(NeedsRecompile "$BOOTIMG_APPENDED_FDT" "$FDT_PATCHED")
        if [ "$RECOMPILE" -eq "1" ];then
            # cleanup
            rm -Rf "$FDTDIR"
            mkdir -p "$FDTDIR"
            rm -Rf "$FDTPATCHEDDIR"
            mkdir -p "$FDTPATCHEDDIR"

            # extract FDT
            "$FDTEXTRACT" "$BOOTIMG_APPENDED_FDT" "$FDTDIR"

            # generate patched dtb's
            echo "$DTBEFIDROIDIFY" "$FDTDIR" "$FDTPATCHEDDIR" "$DTBEFIDROIDIFY_REMOVE_NODES" "$DTBEFIDROIDIFY_FDT_PARSER"
            "$DTBEFIDROIDIFY" "$FDTDIR" "$FDTPATCHEDDIR" "$DTBEFIDROIDIFY_REMOVE_NODES" "$DTBEFIDROIDIFY_FDT_PARSER"

            # create new fdt.img
            cat "$FDTPATCHEDDIR/"* > "$FDT_PATCHED"

            CreateModTimeFile "$BOOTIMG_APPENDED_FDT" "$FDT_PATCHED"
        fi
    fi
}


########################################
#                 LK                   #
########################################

CompileLKKernelFinal() {
    if [ ! -z "$BOOTIMG_APPENDED_FDT" ];then
        # header + LK
        LK_SIZE="$(( 0x30 + $(stat -L -c %s $LK_BINARY) ))"

        # write header
        rm -f "$LK_BINARY_FINAL"
        rm -f "$LK_BINARY_FINAL_ORIGDTB"
        GenerateKernelHeader "$LK_SIZE" "$LK_BINARY_FINAL"

        # write LK, duplicate for origdtb version
        cat "$LK_BINARY" >> "$LK_BINARY_FINAL"
        cp "$LK_BINARY_FINAL" "$LK_BINARY_FINAL_ORIGDTB"

        # write fdt
        cat "$FDT_PATCHED" >> "$LK_BINARY_FINAL"
        cat "$BOOTIMG_APPENDED_FDT" >> "$LK_BINARY_FINAL_ORIGDTB"
    else
        cp "$LK_BINARY" "$LK_BINARY_FINAL"
        cp "$LK_BINARY" "$LK_BINARY_FINAL_ORIGDTB"
    fi
}

CompileLKKernel() {
    mkdir -p "$LK_OUT"
    "$EFIDROID_SHELL" -c "$LK_ENV_NOUEFI \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
    GeneratePatchedDeviceTree
    CompileLKKernelFinal
}

CompileLKBootImage() {
    pr_alert "Installing: $DEVICE_OUT/lk.img"
    set -x
    "$TOP/build/tools/mkbootimg" \
        --kernel "$LK_BINARY_FINAL" \
        --ramdisk /dev/null \
        --base "$BOOTIMG_BASE" \
        $LK_MKBOOTIMG_ADDITIONAL_FLAGS \
        -o "$DEVICE_OUT/lk.img"
    set +x

    if [ ! -z "$BOOTIMG_DT" ] || [ ! -z "$BOOTIMG_APPENDED_FDT" ]; then
        pr_alert "Installing: $DEVICE_OUT/lk_origdtb.img"
        set -x
        "$TOP/build/tools/mkbootimg" \
            --kernel "$LK_BINARY_FINAL_ORIGDTB" \
            --ramdisk /dev/null \
            --base "$BOOTIMG_BASE" \
            $LK_MKBOOTIMG_ADDITIONAL_FLAGS_ORIGDTB \
            -o "$DEVICE_OUT/lk_origdtb.img"
        set +x
    fi
}


########################################
#                UEFI                  #
########################################

CompileLKUEFIKernel() {
    mkdir -p "$LK_OUT"
    "$EFIDROID_SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET"
}

CompileLKUEFIKernelFinal() {
    C="$LK_OUT/tmp.c"
    BIN="$LK_OUT/tmp"
    LKEDK2BIN="$LK_OUT/build-$LK_TARGET/lk-edk2.bin"
    EDK2_SIZE="$(stat -L -c %s $EDK2_BIN)"

    rm -f "$LK_BINARY_FINAL"

    # write header
    if [ ! -z "$BOOTIMG_APPENDED_FDT" ];then
        # header + LK + edk2size + EDK2
        LKEDK2_SIZE="$(( 0x30 + $(stat -L -c %s $LK_BINARY) + 8 + $(stat -L -c %s $EDK2_BIN)))"

        # write header
        GenerateKernelHeader "$LKEDK2_SIZE" "$LK_BINARY_FINAL"
    fi

    # write LK
    cat "$LK_BINARY" >> "$LK_BINARY_FINAL"

    # generate C file
    echo "#include <unistd.h>" > "$C"
    echo "#include <stdint.h>" >> "$C"
    echo "int main(void){uint32_t n;" >> "$C"
    echo "n=$EDK2_BASE; write(1, &n, sizeof(n));" >> "$C"
    echo "n=$EDK2_SIZE; write(1, &n, sizeof(n));" >> "$C"
    echo "return 0;" >> "$C"
    echo "}" >> "$C"

    # compile C file
    gcc -Wall -Wextra -Wshadow -Werror "$C" -o "$BIN"

    # write size
    "$BIN" >> "$LK_BINARY_FINAL"

    # write EDK2
    cat "$EDK2_BIN" >> "$LK_BINARY_FINAL"

    GeneratePatchedDeviceTree

    # appended fdt
    if [ ! -z "$BOOTIMG_APPENDED_FDT" ];then
        cat "$FDT_PATCHED" >> "$LK_BINARY_FINAL"
    fi
}

CompileUEFIBootImage() {
    # generate meta data
    "$TOP/build/tools/create_efidroid_metadata" "$DEVICE" > "$DEVICE_OUT/efidroid_meta.bin"

    for part in $DEVICE_UEFI_PARTITIONS; do
        pr_alert "Installing: $DEVICE_OUT/uefi_$part.img"
        set -x
        "$TOP/build/tools/mkbootimg" \
            --kernel "$LK_BINARY_FINAL" \
            --ramdisk /dev/null \
            --base "$BOOTIMG_BASE" \
            --cmdline "uefi.bootpart=$part" \
            $LK_MKBOOTIMG_ADDITIONAL_FLAGS \
            -o "$DEVICE_OUT/uefi_$part.img"
        set +x
        cat "$DEVICE_OUT/efidroid_meta.bin" >> "$DEVICE_OUT/uefi_$part.img"
    done
}


########################################
#              CLEANUP                 #
########################################

Clean() {
    "$EFIDROID_SHELL" -c "$LK_ENV \"$MAKEFORWARD\" \"$EFIDROID_MAKE\" -C \"$LK_DIR\" $LK_TARGET clean"
}

DistClean() {
    rm -Rf $LK_OUT/*
}
