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

    def getNVVarsPartition(self):
        for entry in self.entries:
            if 'nvvars' in entry.fs_options:
                return entry.blk_device

        return None
