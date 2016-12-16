#!/usr/bin/env fish
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

# Ported to fish shell by Luca Weiss <luca (at) z3ntu (dot) xyz>

set -x TOP (pwd)

set -x PATH "$TOP/build/tools" $PATH

# add some common out directories
set -x PATH "$TOP/out/host/dtbtools" $PATH
set -x PATH "$TOP/out/host/dtc/dtc" $PATH

function croot
    cd "$TOP"
end

function mkefidroid
    make -C "$TOP" $argv
end

function lunch
    # generate and include config
    mkdir -p "$TOP/out"
    eval "$TOP/build/tools/generate_build_env" "$TOP/out/build_env.sh" $argv
    source "$TOP/out/build_env.sh"
    rm "$TOP/out/build_env.sh"

    # set prompt
    if [ ! $STAY_OFF_MY_LAWN ]
        if not functions -q _old_fish_prompt # if the function doesn't already exist
            functions -c fish_prompt _old_fish_prompt # copy current prompt to backup
            
            function fish_prompt # declare new prompt
                echo -ne "[$EFIDROID_DEVICEID|$EFIDROID_BUILDTYPE] "(_old_fish_prompt) # just prepend deviceid&buildtype
            end
            
            function restore_prompt # create function to restore old prompt
                functions -e fish_prompt # erase current prompt
                functions -c _old_fish_prompt fish_prompt # copy old prompt
                functions -e _old_fish_prompt # erase old prompt
                functions -e restore_prompt # self destruct
                echo "Old prompt restored."
            end
            echo "New prompt set. To restore the old prompt, call 'restore_prompt'."
        end
    end
end
