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

SELINUX_SRC=""
SELINUX_MAKE_ARGS=""

Compile() {
    SELINUX_SRC="$TOP/modules/selinux_7"

    # link sources
    if [ ! -d "$MODULE_OUT/libselinux/" ];then
        "$TOP/build/tools/lns" -rf "$SELINUX_SRC/libselinux/" "$MODULE_OUT"
    fi

    # make
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/libselinux" $SELINUX_MAKE_ARGS all
}

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/libselinux" $SELINUX_MAKE_ARGS clean
}

DistClean() {
    rm -Rf "$MODULE_OUT/"*
}
