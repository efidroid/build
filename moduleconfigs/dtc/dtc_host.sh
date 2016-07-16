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

Compile() {
    "$TOP/build/tools/lns" -rf "$MODULE_DIR/" "$MODULE_OUT"
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS
}

Clean() {
    if [ -f "$MODULE_OUT/dtc" ];then 
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_OUT/dtc" $DTC_MAKE_ARGS clean
    fi
}

DistClean() {
    rm -Rf "$MODULE_OUT/"*
}
