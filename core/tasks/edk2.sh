EDK2_OUT="$MODULE_OUT"
EDK2_DIR="$TOP/uefi/edk2"
EDK2_ENV="GCC49_ARM_PREFIX=$GCC_LINUX_GNUEABIHF MAKEFLAGS="
EDK2_BIN="$EDK2_OUT/Build/LittleKernelPkg/DEBUG_GCC49/FV/LITTLEKERNELPKG_EFI.fd"
EDK2_EFIDROID_OUT="$EDK2_OUT/Build/EFIDROID"
EDK2_FDF_INC="$EDK2_EFIDROID_OUT/LittleKernelPkg.fdf.inc"

# default values
if [ -z "$DRAM_BASE" ];then
    DRAM_BASE="$EDK2_BASE"
fi
if [ -z "$DRAM_SIZE" ];then
    DRAM_SIZE="0x01000000" # 16MB
fi
if [ -z "$EDK2_BASE" ];then
    # LK + LKSIZE + FRAMEBUFFER(8MB for now)
    EDK2_BASE=$(printf "0x%x" $(($LK_BASE + 0x400000 + 0x800000)))
fi

if [ -z "$EDK2_BASE" ];then
    pr_fatal "EDK2_BASE is not set"
fi
if [ -z "$DRAM_BASE" ];then
    pr_fatal "DRAM_BASE is not set"
fi
if [ -z "$DRAM_SIZE" ];then
    pr_fatal "DRAM_SIZE is not set"
fi

# set global variables
setvar "EDK2_BIN" "$EDK2_BIN"
setvar "EDK2_BASE" "$EDK2_BASE"

Configure() {
	# setup build directory
	mkdir -p "$EDK2_OUT"
	mkdir -p "$EDK2_EFIDROID_OUT"
	"$TOP/build/tools/edk2_update" "$EDK2_DIR" "$EDK2_OUT"
	
	# generate FDF include file
	echo -e "DEFINE FD_BASE = $EDK2_BASE\n" > "$EDK2_FDF_INC"
	echo -e "DEFINE EFIDROID_MULTIBOOT_BIN = Build/EFIDROID/multiboot_bin\n" >> "$EDK2_FDF_INC"
	
	# get EDK git revision
    tmp=$(cd "$EDK2_DIR" && git rev-parse --verify --short HEAD)
	setvar "EDK2_VERSION" "$tmp"
	
	# (re)compile BaseTools
	MAKEFLAGS= "$EFIDROID_MAKE" -C "$EDK2_OUT/BaseTools"
}

Compile() {
    # copy multiboot binary to workspace
	cp "$TARGET_MULTIBOOT_OUT/init" "$EDK2_EFIDROID_OUT/multiboot_bin"

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))
	
	# compile EDKII
	# Note: using 4 threads here as this seems to be a generic value
	# and the build system ignores this makefile's settings
    "$SHELL" -c "\
	    cd "$EDK2_OUT" && \
		    source edksetup.sh && \
		    $EDK2_ENV build -n$numjobs -a ARM -t GCC49 -p LittleKernelPkg/LittleKernelPkg.dsc \
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
	
	# force rebuild of LK
	touch "$TOP/uefi/lkmodules/uefiapi/edk2bin.c"
}

EDK2Shell() {
    "$SHELL" -c "\
        cd \"$EDK2_OUT\" && \
		    source edksetup.sh && \
		    $EDK2_ENV \"$SHELL\" \
    "
}

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    true
}
