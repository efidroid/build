#!/bin/bash
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

export TOP="$PWD"

croot() {
	cd "$TOP"
}

mkefidroid() {
    make -C "$TOP" $@
}

lunch() {
    mkdir -p "$TOP/out"
    "$TOP/build/tools/generate_build_env" "$TOP/out/build_env.sh"
    source "$TOP/out/build_env.sh"
}
