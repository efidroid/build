EDK2_BUILD_TYPE="$BUILDTYPE"

EDK2_OUT="$MODULE_OUT"
EDK2_DIR="$TOP/uefi/edk2"
EDK2_ENV="GCC49_ARM_PREFIX=$GCC_LINUX_GNUEABIHF MAKEFLAGS="

Compile() {
    # setup build directory
    mkdir -p "$EDK2_OUT"
    "$TOP/build/tools/edk2_update" "$EDK2_DIR" "$EDK2_OUT"

    # (re)compile BaseTools
    MAKEFLAGS= "$EFIDROID_MAKE" -C "$EDK2_OUT/BaseTools"

    cp "$TOP/build/core/tasks/target.txt" "$EDK2_OUT/Conf/target.txt"
    sed -i "s/fstack-protector/fno-stack-protector/g" "$EDK2_OUT/Conf/tools_def.txt"

    # get number of jobs
    MAKEPATH=$($MAKEFORWARD_PIPES)
    plussigns=$(timeout -k 1 1 cat "$MAKEPATH/3" ; exit 0)
    numjobs=$(($(echo -n $plussigns | wc -c) + 1))

    # compile EDKII
    "$SHELL" -c "\
	    cd "$EDK2_OUT" && \
		    source edksetup.sh && \
		    $EDK2_ENV build -n$numjobs -p ArmPkg/ArmPkg.dsc && \
		    $EDK2_ENV build -n$numjobs \
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

Clean() {
    rm -Rf $EDK2_OUT/*
}

DistClean() {
    true
}
