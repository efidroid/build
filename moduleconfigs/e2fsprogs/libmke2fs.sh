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

if [ ! -z "$MODULE_ARCH" ];then
    GCC_PREFIX="${GCC_LINUX_TARGET_PREFIX}"
    E2FSPROGS_OUT="$TARGET_E2FSPROGS_OUT"
else
    GCC_PREFIX=""
    E2FSPROGS_OUT="$HOST_E2FSPROGS_OUT"
fi

Compile() {
   "${GCC_PREFIX}ar" rcs "$MODULE_OUT/libmke2fs.a" \
        "$E2FSPROGS_OUT/misc/mke2fs.o" \
        "$E2FSPROGS_OUT/misc/util.o" \
        "$E2FSPROGS_OUT/misc/default_profile.o" \
        "$E2FSPROGS_OUT/misc/mk_hugefiles.o" \
        "$E2FSPROGS_OUT/misc/create_inode.o"

    "${GCC_PREFIX}objcopy" --redefine-sym main=mke2fs_main "$MODULE_OUT/libmke2fs.a"
}

Clean() {
    rm -f "$MODULE_OUT/libmke2fs.a"
}

DistClean() {
    Clean
}
