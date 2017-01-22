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

if [ "$MODULE_TYPE" == "target" ];then
    LOKI_MAKE_ARGS="$LOKI_MAKE_ARGS AR=${GCC_LINUX_TARGET_PREFIX}ar"
    LOKI_MAKE_ARGS="$LOKI_MAKE_ARGS AS=${GCC_LINUX_TARGET_PREFIX}as"
    LOKI_MAKE_ARGS="$LOKI_MAKE_ARGS CC=${GCC_LINUX_TARGET_PREFIX}gcc"
    LOKI_MAKE_ARGS="$LOKI_MAKE_ARGS CXX=${GCC_LINUX_TARGET_PREFIX}g++"
    LOKI_MAKE_ARGS_STATIC="CFLAGS=\"-static\""
fi

Compile() {
    "$TOP/build/tools/lns" -rf "$MODULE_DIR/" "$MODULE_OUT"

    if [ "$MODULE_TYPE" == "target" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/loki" $LOKI_MAKE_ARGS $LOKI_MAKE_ARGS_STATIC
    else
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/loki" $LOKI_MAKE_ARGS host
    fi
}

Clean() {
    if [ -f "$MODULE_OUT/loki" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/loki" $LOKI_MAKE_ARGS clean
    fi
}

DistClean() {
    rm -Rf "$MODULE_OUT/"*
}
