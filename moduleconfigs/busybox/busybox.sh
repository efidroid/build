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

BB_ARGS="ARCH=arm CROSS_COMPILE=$GCC_LINUX_TARGET_PREFIX O=$MODULE_OUT"

EnableConfig() {
    sed -i "s/# $1 is not set/$1=y/g" "$MODULE_OUT/.config"
}

DisableConfig() {
    sed -i "s/$1=y/# $1 is not set/g" "$MODULE_OUT/.config"
}

Compile() {
    if [ ! -f "$MODULE_OUT/.config" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS allnoconfig
        EnableConfig CONFIG_STATIC
        EnableConfig CONFIG_SED
        EnableConfig CONFIG_LOSETUP
        EnableConfig CONFIG_DD
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_ASH
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_RM
        DisableConfig CONFIG_FEATURE_SH_IS_NONE
        EnableConfig CONFIG_FEATURE_SH_IS_ASH
        EnableConfig CONFIG_LFS
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS silentoldconfig
    fi

    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS all
}

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS clean
}

DistClean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS distclean
}
