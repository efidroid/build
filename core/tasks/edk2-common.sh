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

CompileEDK2() {
    PROJECTCONFIG="$1"
    DEFINES="$2"

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))

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
    echo -n "$plussigns" > "$MAKEPATH/3"
}

EDK2Shell() {
    "$EFIDROID_SHELL" -c "\
        cd \"$EDK2_OUT\" && \
		    source edksetup.sh && \
		    $EDK2_ENV \"$EFIDROID_SHELL\" \
    "
}
