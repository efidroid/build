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

class FSTabEntry:
    blk_device = None
    mount_point = None
    fs_type = None
    flags = []
    fs_options = []

    def __init__(self, blk_device, mount_point, fs_type, flags, fs_options):
        self.blk_device = blk_device
        self.mount_point = mount_point
        self.fs_type = fs_type
        self.flags = flags
        self.fs_options = fs_options
        

class FSTab:
    entries = []

    def __init__(self, filename):
        with open(filename) as f:
            for line in f:
                line = line.strip() # strip whitespace
                line = line.split('#', 1)[0] # remove comments
                if not line:
                    continue

                # get device
                tmp = line.split(' ', 1)
                blk_device = tmp[0]

                # get mountpoint
                tmp = tmp[1].strip().split(' ', 1)
                mount_point = tmp[0]

                # get fs_type
                tmp = tmp[1].strip().split(' ', 1)
                fs_type = tmp[0]

                # get mount flags
                tmp = tmp[1].strip().split(' ', 1)
                flags = tmp[0].split(',')

                if len(tmp)>1:
                    # get fs_options
                    tmp = tmp[1].strip().split(' ', 1)
                    fs_options = tmp[0].split(',')

                self.entries.append(FSTabEntry(blk_device, mount_point, fs_type, flags, fs_options))

    def getOptionValue(self, entry, name):
        for fs_option in entry.fs_options:
            optname = fs_option
            optval = None
            fs_option_kv = fs_option.split('=')
            if len(fs_option_kv)>1:
                optname = fs_option_kv[0]
                optval = fs_option_kv[1]

            if name in optname:
                return optval

    def hasOption(self, entry, name):
        for fs_option in entry.fs_options:
            optname = fs_option
            optval = None
            fs_option_kv = fs_option.split('=')
            if len(fs_option_kv)>1:
                optname = fs_option_kv[0]
                optval = fs_option_kv[1]

            if name in optname:
                return True

        return False

    def getNVVarsPartition(self):
        for entry in self.entries:
            if 'nvvars' in entry.fs_options:
                return entry.blk_device

        return None

    def getESPPartition(self):
        for entry in self.entries:
            if self.hasOption(entry, 'esp'):
                path = self.getOptionValue(entry, 'esp')
                if 'datamedia' in path:
                    path = 'media'
                elif path[0] == '/':
                    pass
                else:
                    raise Exception('Invalid ESP value in fstab: %s' % (path))

                return [entry.blk_device, path]

        return None

    def getUEFIPartitionNameList(self):
        rc = []
        for entry in self.entries:
            if 'uefi' in entry.fs_options:
                if entry.fs_type != 'emmc':
                    raise Exception('UEFI partition %s is not of type emmc' % (entry.blk_device))

                rc.append(entry.mount_point[1:])

        return rc

    def partitionpath2name(self, part):
        tmp = part.split('/by-name/')
        if len(tmp) !=2:
            raise Exception('Invalid partition path: %s'  % (part))

        return tmp[1]
