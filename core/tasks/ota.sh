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

ZIPNAME="$TARGET_OUT/otapackage-$(date +'%Y%m%d')-${DEVICE/\//_}.zip"

BuildOtaPackage() {
    Clean

    # copy UEFI partition images
    for part in $DEVICE_UEFI_PARTITIONS; do
        cp "$TARGET_OUT/uefi_$part.img" "$MODULE_OUT/$part.img"
    done

    # create zip

    cd "$MODULE_OUT" &&
        zip -r "$ZIPNAME" .

    pr_alert "Installing: $ZIPNAME"
}

PublishRelease() {
    RELEASEDIR="$TOP/ota/$DEVICE"

    mkdir -p "$RELEASEDIR"

    "$TOP/build/tools/publish_release" "$RELEASEDIR" "$ZIPNAME"
}


########################################
#              CLEANUP                 #
########################################

Clean() {
    rm -Rf "$MODULE_OUT/"*
}

DistClean() {
    Clean
}
