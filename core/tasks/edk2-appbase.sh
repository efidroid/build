source "$TOP/build/core/tasks/edk2-common.sh"

# set build type
EDK2_BUILD_TYPE="$BUILDTYPE"

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

    # compile MdePkg
    CompileEDK2 "$MdePkg/MdePkg.dsc"
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

    # compile
    CompileEDK2 "$APPCONFIG_REL"

    # print binary path
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
