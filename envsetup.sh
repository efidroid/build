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

export PATH="$TOP/build/tools:$PATH"

# add some common out directories
export PATH="$TOP/out/host/dtbtools:$PATH"
export PATH="$TOP/out/host/dtc/dtc:$PATH"

croot() {
    cd "$TOP"
}

mkefidroid() {
    make -C "$TOP" $@
}

lunch() {
    # generate and include config
    mkdir -p "$TOP/out"
    "$TOP/build/tools/generate_build_env" "$TOP/out/build_env.sh" "$@"
    source "$TOP/out/build_env.sh"
    rm "$TOP/out/build_env.sh"

    # set window title
    if [ "$STAY_OFF_MY_LAWN" = "" ]; then
        export PROMPT_COMMAND="echo -ne \"\033]0;[$EFIDROID_DEVICEID|$EFIDROID_BUILDTYPE] ${USER}@${HOSTNAME}: ${PWD}\007\""
    fi
}
