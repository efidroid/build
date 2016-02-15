EDK2_BUILD_TYPE="$BUILDTYPE"

EDK2_OUT="$MODULE_OUT"
EDK2_DIR="$TOP/uefi/edk2"
EDK2_ENV="MAKEFLAGS="
EDK2_COMPILER="GCC49"

EDK2_BIN="$EDK2_OUT/Build/LittleKernelPkg/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/FV/LITTLEKERNELPKG_EFI.fd"
EDK2_EFIDROID_OUT="$EDK2_OUT/Build/EFIDROID"
EDK2_FDF_INC="$EDK2_EFIDROID_OUT/LittleKernelPkg.fdf.inc"

if [ "$EFIDROID_TARGET_ARCH" == "arm" ];then
    EDK2_ARCH="ARM"
elif [ "$EFIDROID_TARGET_ARCH" == "x86" ];then
    EDK2_ARCH="IA32"
elif [ "$EFIDROID_TARGET_ARCH" == "x86_64" ];then
    EDK2_ARCH="X64"
elif [ "$EFIDROID_TARGET_ARCH" == "aarch64" ];then
    EDK2_ARCH="AArch64"
fi
EDK2_ENV="$EDK2_ENV ${EDK2_COMPILER}_${EDK2_ARCH}_PREFIX=$GCC_NONE_TARGET_PREFIX"

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
    ln -s "$TOP/out/host/edk2_appbase/Build/EFIDroidUEFIApps" "$EDK2_OUT/Build/EFIDroidUEFIApps"

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

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))

    # compile EDKII
    "$EFIDROID_SHELL" -c "\
	    cd "$EDK2_OUT" && \
		    source edksetup.sh && \
		    $EDK2_ENV build -n$numjobs -b $EDK2_BUILD_TYPE -a ${EDK2_ARCH} -t ${EDK2_COMPILER} -p LittleKernelPkg/LittleKernelPkg.dsc \
			    -DFIRMWARE_VER=$EDK2_VERSION \
			    -DFIRMWARE_VENDOR=EFIDroid \
			    -DDRAM_BASE=$DRAM_BASE \
			    -DDRAM_SIZE=$DRAM_SIZE\
    " 2> >(\
    while read line; do \
        if [[ "$line" =~ "error" ]];then \
            echo -e "\e[01;31m$line\e[0m" >&2; \
        else \
            echo -e "\e[01;32m$line\e[0m" >&2; \
        fi;\
    done)

    # write back our jobs
    echo -n "$plussigns" > "$MAKEPATH/3"
}

EDK2Shell() {
    "$EFIDROID_SHELL" -c "\
        cd \"$EDK2_OUT\" && \
		    source edksetup.sh && \
		    $EDK2_ENV \"$EFIDROID_SHELL\" \
    "
}

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    Clean
}
