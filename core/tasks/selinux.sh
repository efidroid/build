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

SELINUX_MAKE_ARGS="$SELINUX_MAKE_ARGS AR=${GCC_LINUX_TARGET_PREFIX}ar"
SELINUX_MAKE_ARGS="$SELINUX_MAKE_ARGS AS=${GCC_LINUX_TARGET_PREFIX}as"
SELINUX_MAKE_ARGS="$SELINUX_MAKE_ARGS CC=${GCC_LINUX_TARGET_PREFIX}gcc"
SELINUX_MAKE_ARGS="$SELINUX_MAKE_ARGS CXX=${GCC_LINUX_TARGET_PREFIX}g++"
SELINUX_MAKE_ARGS="$SELINUX_MAKE_ARGS CFLAGS=\"-Wno-sign-compare\""

SELINUX_SRC=""
LIB_SUFFIX=""

Compile() {
    if [ "$MODULE_NAME" == "target_libsepol6" ];then
        SELINUX_SRC="$TOP/modules/selinux_6"
        LIB_SUFFIX="6"
    elif [ "$MODULE_NAME" == "target_libsepol7" ];then
        SELINUX_SRC="$TOP/modules/selinux_7"
        LIB_SUFFIX="7"
    else
        pr_fatal "invalid selinux target $MODULE_NAME"
    fi

    MODTIME=0
    LIBFILE_COMPILE="$MODULE_OUT/libsepol/src/libsepol.a"
    LIBFILE_INSTALL="$MODULE_OUT/install/lib/libsepol$LIB_SUFFIX.a"

    # link sources
    if [ ! -d "$SELINUX_SRC/libsepol/" ];then
        "$TOP/build/tools/lns" -rf "$SELINUX_SRC/libsepol/" "$MODULE_OUT"
    fi

    # get modification time
    if [ -f "$LIBFILE_COMPILE" ];then
        MODTIME=$(stat -c %Y "$LIBFILE_COMPILE")
    fi

    # make
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/libsepol" $SELINUX_MAKE_ARGS all

    # check if the lib was modified
    MODTIME_NEW=$(stat -c %Y "$LIBFILE_COMPILE")
    if [ "$MODTIME_NEW" -gt "$MODTIME" ];then
        # copy lib
        mkdir -p "$MODULE_OUT/install/lib"
        cp "$LIBFILE_COMPILE" "$LIBFILE_INSTALL"

        # add prefix to all global symbols
        "${GCC_LINUX_TARGET_PREFIX}objdump" -t "$LIBFILE_INSTALL" | awk '$2 == "g"' | awk "{ print \$6 \" selinux${LIB_SUFFIX}_\" \$6}" > "$MODULE_OUT/redefine.syms"
        "${GCC_LINUX_TARGET_PREFIX}objcopy" --redefine-syms "$MODULE_OUT/redefine.syms" "$LIBFILE_INSTALL"

        # show path
        pr_alert "Installing: $LIBFILE_INSTALL"

        # install headers
        mkdir -p "$MODULE_OUT/install/include"
        "$TOP/build/tools/headers_install" -j8 -s "selinux${LIB_SUFFIX}" -p "selinux${LIB_SUFFIX}" -r "$MODULE_OUT/redefine.syms" "$SELINUX_SRC/libsepol/include/" "$MODULE_OUT/install/include"
    fi
}

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/libsepol" $SELINUX_MAKE_ARGS clean
}

DistClean() {
    rm -Rf "$MODULE_OUT/"*
}
