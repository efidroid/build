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

if [[ "$PATH" != ?(*:)"$TOP/build/tools"?(:*) ]]; then
    export PATH="$TOP/build/tools:$PATH"
fi

# add some common out directories
if [[ "$PATH" != ?(*:)"$TOP/out/host/dtbtools"?(:*) ]]; then
    export PATH="$TOP/out/host/dtbtools:$PATH"
fi
if [[ "$PATH" != ?(*:)"$TOP/out/host/dtc/dtc"?(:*) ]]; then
    export PATH="$TOP/out/host/dtc/dtc:$PATH"
fi

croot() {
    cd "$TOP"
}

mkefidroid() {
    make -C "$TOP" $@
}

lunch() {
    # cleanup
    mkdir -p "$TOP/out"
    rm -f "$TOP/out/build_env.sh"

    # generate
    "$TOP/build/tools/generate_build_env" "$TOP/out/build_env.sh" "$@"

    # source
    if [ $? -eq 0 ] && [ -f "$TOP/out/build_env.sh" ];then
        source "$TOP/out/build_env.sh"
        rm "$TOP/out/build_env.sh"
    fi

    # set window title
    if [ "$STAY_OFF_MY_LAWN" = "" ]; then
        if [ -n "$EFIDROID_DEVICEID" ]; then
            export EFIDROID_PROMPT_COMMAND_BACKUP="$PROMPT_COMMAND"
            export PROMPT_COMMAND="echo -ne \"\033]0;[$EFIDROID_DEVICEID|$EFIDROID_BUILDTYPE] ${USER}@${HOSTNAME}: ${PWD}\007\""
        elif [ -n "$EFIDROID_PROMPT_COMMAND_BACKUP" ];then
            export PROMPT_COMMAND="$EFIDROID_PROMPT_COMMAND_BACKUP"
            unset EFIDROID_PROMPT_COMMAND_BACKUP
        fi
    fi
}
