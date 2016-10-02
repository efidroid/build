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
    DTC_MAKE_ARGS="$DTC_MAKE_ARGS AR=${GCC_LINUX_TARGET_PREFIX}ar"
    DTC_MAKE_ARGS="$DTC_MAKE_ARGS AS=${GCC_LINUX_TARGET_PREFIX}as"
    DTC_MAKE_ARGS="$DTC_MAKE_ARGS CC=${GCC_LINUX_TARGET_PREFIX}gcc"
    DTC_MAKE_ARGS="$DTC_MAKE_ARGS CXX=${GCC_LINUX_TARGET_PREFIX}g++"
    DTC_MAKE_ARGS_STATIC="CFLAGS=\"-static\""
fi

Compile() {
    "$TOP/build/tools/lns" -rf "$MODULE_DIR/" "$MODULE_OUT"

    if [ "$MODULE_TYPE" == "target" ];then
        # compile supported targets only
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS libfdt
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS $DTC_MAKE_ARGS_STATIC convert-dtsv0 dtc fdtdump fdtget fdtput
    else
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS
    fi
}

Clean() {
    if [ -f "$MODULE_OUT/dtc" ];then 
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS clean
    fi
}

DistClean() {
    rm -Rf "$MODULE_OUT/"*
}
