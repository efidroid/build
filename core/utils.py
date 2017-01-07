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

import sys

# color codes
txtblk='\033[0;30m' # Black - Regular
txtred='\033[0;31m' # Red
txtgrn='\033[0;32m' # Green
txtylw='\033[0;33m' # Yellow
txtblu='\033[0;34m' # Blue
txtpur='\033[0;35m' # Purple
txtcyn='\033[0;36m' # Cyan
txtwht='\033[0;37m' # White
bldblk='\033[1;30m' # Black - Bold
bldred='\033[1;31m' # Red
bldgrn='\033[1;32m' # Green
bldylw='\033[1;33m' # Yellow
bldblu='\033[1;34m' # Blue
bldpur='\033[1;35m' # Purple
bldcyn='\033[1;36m' # Cyan
bldwht='\033[1;37m' # White
unkblk='\033[4;30m' # Black - Underline
undred='\033[4;31m' # Red
undgrn='\033[4;32m' # Green
undylw='\033[4;33m' # Yellow
undblu='\033[4;34m' # Blue
undpur='\033[4;35m' # Purple
undcyn='\033[4;36m' # Cyan
undwht='\033[4;37m' # White
bakblk='\033[40m'   # Black - Background
bakred='\033[41m'   # Red
bakgrn='\033[42m'   # Green
bakylw='\033[43m'   # Yellow
bakblu='\033[44m'   # Blue
bakpur='\033[45m'   # Purple
bakcyn='\033[46m'   # Cyan
bakwht='\033[47m'   # White
txtrst='\033[0m'    # Text Reset

# global variables
class Bunch:
    def __init__(self, **kwds):
        self.__dict__.update(kwds)
    def __iter__(self):
        return self.__dict__.iteritems()
    def __str__(self):
        return self.__dict__.__str__()
    def __repr__(self):
        return self.__dict__.__repr__()
cfg = Bunch()

def pr_error(*args):
    print(bldred+" ".join(map(str,args))+txtrst)
def pr_fatal(*args):
    pr_error(" ".join(map(str,args)))
    sys.exit(1)
def pr_info(*args):
    print(bldwht+" ".join(map(str,args))+txtrst)
def pr_warning(*args):
    print(bldylw+" ".join(map(str,args))+txtrst)
def pr_notice(*args):
    print(bldcyn+" ".join(map(str,args))+txtrst)
def pr_alert(*args):
    print(bldgrn+" ".join(map(str,args))+txtrst)

def inputex(msg):
    prompt = bldylw+msg+txtrst

    try:
        return raw_input(prompt)
    except KeyboardInterrupt:
        raise
    except:
        return input(prompt)

def runmain(main):
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print('\n'+bldred+'Aborted by user.'+txtrst)
        sys.exit(1)
    except SystemExit as e:
        if e.code:
            pr_error('Error: %s' % e.code)
        raise
    except:
        pr_error('Error: %s' % sys.exc_info()[1])
        raise
