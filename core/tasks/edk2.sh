source "$TOP/build/core/tasks/edk2-common.sh"

# set build type
EDK2_BUILD_TYPE="$BUILDTYPE"

# check required variables
if [ -z "$EDK2_BASE" ];then
    pr_fatal "EDK2_BASE is not set"
fi

# default values
if [ -z "$DRAM_BASE" ];then
    DRAM_BASE="$EDK2_BASE"
fi
if [ -z "$DRAM_SIZE" ];then
    DRAM_SIZE="0x01000000" # 16MB
fi

EDK2_BIN="$EDK2_OUT/Build/LittleKernelPkg/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/FV/LITTLEKERNELPKG_EFI.fd"
EDK2_EFIDROID_OUT="$EDK2_OUT/Build/EFIDROID"
EDK2_FDF_INC="$EDK2_EFIDROID_OUT/LittleKernelPkg.fdf.inc"
EDK2_DEFINES="$EDK2_DEFINES -DFIRMWARE_VER=$EDK2_VERSION"
EDK2_DEFINES="$EDK2_DEFINES -DFIRMWARE_VENDOR=EFIDroid"
EDK2_DEFINES="$EDK2_DEFINES -DDRAM_BASE=$DRAM_BASE"
EDK2_DEFINES="$EDK2_DEFINES -DDRAM_SIZE=$DRAM_SIZE"

# set global variables
setvar "EDK2_BIN" "$EDK2_BIN"
setvar "EDK2_BASE" "$EDK2_BASE"

Configure() {
    # setup build directory
    mkdir -p "$EDK2_OUT"
    mkdir -p "$EDK2_EFIDROID_OUT"
    "$TOP/build/tools/edk2_update" "$EDK2_DIR" "$EDK2_OUT"

    # link apps
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps"
    ln -s "$TARGET_COMMON_OUT/uefiapp_EFIDroidUi/Build/EFIDroidUEFIApps" "$EDK2_OUT/Build/EFIDroidUEFIApps"

    # generate FDF include file
    echo -e "DEFINE FD_BASE = $EDK2_BASE\n" > "$EDK2_FDF_INC"
    echo -e "DEFINE EFIDROID_UEFIRD        = Build/EFIDROID/uefird.cpio\n" >> "$EDK2_FDF_INC"

    # get EDK git revision
    tmp=$(cd "$EDK2_DIR" && git rev-parse --verify --short HEAD)
    setvar "EDK2_VERSION" "$tmp"

    # (re)compile BaseTools
    MAKEFLAGS= "$EFIDROID_MAKE" -C "$EDK2_OUT/BaseTools"
}

Compile() {
    # copy required files to workspace
    cp "$UEFIRD_CPIO" "$EDK2_EFIDROID_OUT/uefird.cpio"

    # compile
    CompileEDK2 "LittleKernelPkg/LittleKernelPkg.dsc" "$EDK2_DEFINES"
}

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    Clean
}
