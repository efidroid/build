REFIND_IDFILE="$MODULE_OUT/.setup_done"
EDK2_APPBASE="$HOST_EDK2_APPBASE_OUT"
EDK2_APPBASE_SED="$(echo $EDK2_APPBASE | sed -e 's/[\/&]/\\&/g')"
GCC_LINUX_GNUEABIHF_SED="$(echo $GCC_LINUX_GNUEABIHF | sed -e 's/[\/&]/\\&/g')"
REFIND_INCMK_SED="$(echo $REFIND_CONFIG_DIR/inc.mk | sed -e 's/[\/&]/\\&/g')"

MakeCopy() {
    PATHNAME="$1"
    rm "$MODULE_OUT/$PATHNAME"
    cp "$MODULE_DIR/$PATHNAME" "$MODULE_OUT/$PATHNAME"
}

AddPcd() {
    FILE="$1"
    echo -e "#define _PCD_VALUE_PcdFixedDebugPrintErrorLevel  0xFFFFFFFF\n" >> "$FILE"
    echo -e "GLOBAL_REMOVE_IF_UNREFERENCED const UINT32 _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel = _PCD_VALUE_PcdFixedDebugPrintErrorLevel;\n" >> "$FILE"
    echo -e "extern const UINT32 _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel;\n" >> "$FILE"
    echo -e "#define _PCD_GET_MODE_32_PcdFixedDebugPrintErrorLevel  _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel\n" >> "$FILE"
    echo -e "#define _PCD_SET_MODE_32_PcdFixedDebugPrintErrorLevel  ASSERT(FALSE)  // It is not allowed to set value for a FIXED_AT_BUILD PCD\n" "$FILE"
}

AddCompilerSetup() {
    FILE="$1"
    sed -i "s/^HOSTARCH.*/HOSTARCH = armv7l/g" "$FILE"
    sed -i "s/^EDK2BASE.*/EDK2BASE = $EDK2_APPBASE_SED\ninclude $REFIND_INCMK_SED/g" "$FILE"
    sed -i "s/^prefix.*/prefix = $GCC_LINUX_GNUEABIHF_SED/g" "$FILE"
    sed -i "s/gcc4.4-ld-script/GccBase.lds/g" "$FILE"
    echo -e "\nLDFLAGS += --defsym=PECOFF_HEADER_SIZE=0x220\n" >> "$FILE"
}

AddEfiLibs() {
    FILE="$1"
    echo -e "\nALL_EFILIBS += \$(EDK2BASE)/Build/Arm/\$(TARGET)_\$(TOOL_CHAIN_TAG)/\$(UC_ARCH)/ArmPkg/Library/CompilerIntrinsicsLib/CompilerIntrinsicsLib/OUTPUT/CompilerIntrinsicsLib.lib\n" >> "$FILE"
}

Compile() {
    if [ ! -f "$REFIND_IDFILE" ];then
        rm -Rf "$MODULE_OUT"
        "$TOP/build/tools/lns" -rf "$MODULE_DIR" "$MODULE_OUT"

        # main
        MakeCopy Make.tiano
        AddCompilerSetup "$MODULE_OUT/Make.tiano"

        # refind
        MakeCopy refind/Make.tiano
        AddEfiLibs "$MODULE_OUT/refind/Make.tiano"

        MakeCopy refind/AutoGen.c
        AddPcd "$MODULE_OUT/refind/AutoGen.c"

        MakeCopy refind/main.c
        cd "$MODULE_OUT" && patch -p1 < "$REFIND_CONFIG_DIR/refind.patch"

        # gptsync
        MakeCopy gptsync/Make.tiano
        AddCompilerSetup "$MODULE_OUT/gptsync/Make.tiano"
        AddEfiLibs "$MODULE_OUT/gptsync/Make.tiano"

        MakeCopy gptsync/AutoGen.c
        AddPcd "$MODULE_OUT/gptsync/AutoGen.c"

        MakeCopy gptsync/gptsync.h
        sed -i "s/defined(EFIAARCH64)/defined(EFIAARCH64) || defined(EFIARM)/g" "$MODULE_OUT/gptsync/gptsync.h"

        touch "$REFIND_IDFILE"
    fi

    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT" tiano
}

Clean() {
    if [ -f "$REFIND_IDFILE" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT" clean
    fi
}

DistClean() {
    true
}
