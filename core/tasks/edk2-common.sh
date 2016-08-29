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

#
# Declare bits for PcdDebugPropertyMask
#
DEBUG_PROPERTY_DEBUG_ASSERT_ENABLED=0x01
DEBUG_PROPERTY_DEBUG_PRINT_ENABLED=0x02
DEBUG_PROPERTY_DEBUG_CODE_ENABLED=0x04
DEBUG_PROPERTY_CLEAR_MEMORY_ENABLED=0x08
DEBUG_PROPERTY_ASSERT_BREAKPOINT_ENABLED=0x10
DEBUG_PROPERTY_ASSERT_DEADLOOP_ENABLED=0x20

#
# Declare bits for PcdDebugPrintErrorLevel and the ErrorLevel parameter of DebugPrint()
#
DEBUG_INIT=0x00000001     # Initialization
DEBUG_WARN=0x00000002     # Warnings
DEBUG_LOAD=0x00000004     # Load events
DEBUG_FS=0x00000008       # EFI File system
DEBUG_POOL=0x00000010     # Alloc & Free's
DEBUG_PAGE=0x00000020     # Alloc & Free's
DEBUG_INFO=0x00000040     # Informational debug messages
DEBUG_DISPATCH=0x00000080 # PEI/DXE/SMM Dispatchers
DEBUG_VARIABLE=0x00000100 # Variable
DEBUG_BM=0x00000400       # Boot Manager
DEBUG_BLKIO=0x00001000    # BlkIo Driver
DEBUG_NET=0x00004000      # SNI Driver
DEBUG_UNDI=0x00010000     # UNDI Driver
DEBUG_LOADFILE=0x00020000 # UNDI Driver
DEBUG_EVENT=0x00080000    # Event messages
DEBUG_GCD=0x00100000      # Global Coherency Database changes
DEBUG_CACHE=0x00200000    # Memory range cachability changes
DEBUG_VERBOSE=0x00400000  # Detailed debug messages that may significantly impact boot performance
DEBUG_ERROR=0x80000000    # Error

setflag_printlevel() {
    FLAGS="$1"

    EDK2_PRINT_ERROR_LEVEL=$(printf "0x%x" $(( $EDK2_PRINT_ERROR_LEVEL | $FLAGS )) )
}

setflag_propertymask() {
    FLAGS="$1"

    EDK2_PROPERTY_MASK=$(printf "0x%x" $(( $EDK2_PROPERTY_MASK | $FLAGS )) )
}

# determine edk2 tool def to use
gcc_version=$("${GCC_NONE_TARGET_PREFIX}gcc" -v 2>&1 | tail -1 | awk '{print $3}')
case $gcc_version in
  4.5.*)
    EDK2_COMPILER=GCC45
    ;;
  4.6.*)
    EDK2_COMPILER=GCC46
    ;;
  4.7.*)
    EDK2_COMPILER=GCC47
    ;;
  4.8.*)
    EDK2_COMPILER=GCC48
    ;;
  4.9.*|4.1[0-9].*)
    EDK2_COMPILER=GCC49
    ;;
  5.*.*|6.*.*)
    EDK2_COMPILER=GCC5
    ;;
  *)
    EDK2_COMPILER=GCC44
    ;;
esac

EDK2_OUT="$MODULE_OUT"
EDK2_DIR="$TOP/uefi/edk2"
EDK2_ENV="MAKEFLAGS="
EDK2_PRINT_ERROR_LEVEL="0"
EDK2_PROPERTY_MASK="0"

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
EDK2_ENV="$EDK2_ENV PACKAGES_PATH=${EDK2_OUT}:${EDK2_DIR}:$TOP/uefi/edk2packages"

EDK2Setup() {
    # copy base files (if changed)
    mkdir -p "$EDK2_OUT"
    cp -Rpu "$EDK2_DIR/BaseTools" "$EDK2_OUT/"
    cp -Rpu "$EDK2_DIR/Conf" "$EDK2_OUT/"
    ln -fs "$EDK2_DIR/edksetup.sh" "$EDK2_OUT/"

    # symlink uefi/apps
    rm -f "$EDK2_OUT/EFIDroidUEFIApps"
    ln -s "$TOP/uefi/apps" "$EDK2_OUT/EFIDroidUEFIApps"

    # symlink modules
    rm -f "$EDK2_OUT/EFIDroidModules"
    ln -s "$TOP/modules" "$EDK2_OUT/EFIDroidModules"

    # (re)compile BaseTools
    "$EFIDROID_SHELL" -c "\
        unset ARCH && \
        unset MAKEFLAGS && \
        \"$EFIDROID_MAKE\" -C \"$EDK2_OUT/BaseTools\" \
    "
}

CompileEDK2() {
    PROJECTCONFIG="$1"
    DEFINES="$2"

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD)
    if [ -p "$MAKEPATH/3" ];then
        plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
        numjobs=$(($(echo -n $plussigns | wc -c) + 1))
    else
        numjobs=1
    fi

    # compile EDKII
    "$EFIDROID_SHELL" -c "\
        cd "$EDK2_OUT" && \
            source edksetup.sh && \
            $EDK2_ENV build -n$numjobs -b ${EDK2_BUILD_TYPE} -a ${EDK2_ARCH} -t ${EDK2_COMPILER} -p ${PROJECTCONFIG} \
                ${DEFINES} \
    " 2> >(\
    while read line; do \
        if [[ "$line" =~ "error" ]];then \
            echo -e "\e[01;31m$line\e[0m" >&2; \
        else \
            echo -e "\e[01;32m$line\e[0m" >&2; \
        fi;\
    done)

    # write back our jobs
    if [ -p "$MAKEPATH/3" ];then
        echo -n "$plussigns" > "$MAKEPATH/3"
    fi
}

EDK2Shell() {
    "$EFIDROID_SHELL" -c "\
        cd \"$EDK2_OUT\" && \
            source edksetup.sh && \
            $EDK2_ENV \"$EFIDROID_SHELL\" \
    "
}
