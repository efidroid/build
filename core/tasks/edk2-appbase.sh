EDK2_BUILD_TYPE="$BUILDTYPE"

EDK2_OUT="$MODULE_OUT"
EDK2_DIR="$TOP/uefi/edk2"
EDK2_ENV="MAKEFLAGS="
EDK2_COMPILER="GCC49"

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

Setup() {
    # setup build directory
    mkdir -p "$EDK2_OUT"
    "$TOP/build/tools/edk2_update" "$EDK2_DIR" "$EDK2_OUT"

    # symlink uefi/apps
    ln -s "$TOP/uefi/apps" "$EDK2_OUT/EFIDroidUEFIApps"

    # symlink modules
    ln -s "$TOP/modules" "$EDK2_OUT/EFIDroidModules"

    # (re)compile BaseTools
    MAKEFLAGS= "$EFIDROID_MAKE" -C "$EDK2_OUT/BaseTools"

    cp "$EDK2_OUT/BaseTools/Conf/tools_def.template" "$EDK2_OUT/Conf/tools_def.txt"
    sed -i "s/fstack-protector/fno-stack-protector/g" "$EDK2_OUT/Conf/tools_def.txt"
}

Compile() {
    # setup
    Setup

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))

    # compile EDKII
    "$EFIDROID_SHELL" -c "\
	    cd "$EDK2_OUT" && \
		    source edksetup.sh && \
		    $EDK2_ENV build -n$numjobs -b $EDK2_BUILD_TYPE -a $EDK2_ARCH -t $EDK2_COMPILER -p MdePkg/MdePkg.dsc \
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

CompileApp() {
    # get app info
    APPNAME="${UEFIAPP##*/}"
    APPCONFIG_REL="Conf/UEFIApp_$APPNAME.dsc"
    APPCONFIG="$EDK2_OUT/$APPCONFIG_REL"

    # setup
    Setup

    # build dsc file
    cp "$TOP/build/core/EFIDroidUEFIApps.dsc" "$APPCONFIG"
    sed -i "s/\[Components\]/\[Components\]\n  EFIDroidUEFIApps\/$APPNAME\/$APPNAME.inf/g" "$APPCONFIG"

    if [ -f "$EDK2_OUT/EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc.inc" ];then
        echo -e "\n!include EFIDroidUEFIApps/$APPNAME/$APPNAME.dsc.inc" >> "$APPCONFIG"
    fi

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))

    # compile EDKII
    "$EFIDROID_SHELL" -c "\
	    cd "$EDK2_OUT" && \
		    source edksetup.sh && \
		    $EDK2_ENV build -n$numjobs -b $EDK2_BUILD_TYPE -a $EDK2_ARCH -t $EDK2_COMPILER -p $APPCONFIG_REL \
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

    BASENAME=$(awk -F "=" '/BASE_NAME/ {print $2}' "$UEFIAPP/$APPNAME.inf" | tr -d '[[:space:]]')
    pr_alert "Installing: $EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"
}

Clean() {
    # get app info
    APPNAME="${UEFIAPP##*/}"
    BASENAME=$(awk -F "=" '/BASE_NAME/ {print $2}' "$UEFIAPP/$APPNAME.inf" | tr -d '[[:space:]]')
    EFIPATH="$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"

    # remove build files
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.efi"
    rm -f "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/$BASENAME.debug"
    rm -Rf "$EDK2_OUT/Build/EFIDroidUEFIApps/${EDK2_BUILD_TYPE}_${EDK2_COMPILER}/$EDK2_ARCH/EFIDroidUEFIApps/$BASENAME"
}

DistClean() {
    rm -Rf $EDK2_OUT/*
}
