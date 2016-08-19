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

BB_ARGS="ARCH=arm CROSS_COMPILE=$GCC_LINUX_TARGET_PREFIX O=$MODULE_OUT"

EnableConfig() {
    sed -i "s/# $1 is not set/$1=y/g" "$MODULE_OUT/.config"
}

DisableConfig() {
    sed -i "s/$1=y/# $1 is not set/g" "$MODULE_OUT/.config"
}

Compile() {
    if [ ! -f "$MODULE_OUT/.config" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS allnoconfig
        EnableConfig CONFIG_STATIC
        EnableConfig CONFIG_SED
        EnableConfig CONFIG_LOSETUP
        EnableConfig CONFIG_DD
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_ASH
        EnableConfig CONFIG_RM
        DisableConfig CONFIG_FEATURE_SH_IS_NONE
        EnableConfig CONFIG_FEATURE_SH_IS_ASH
        EnableConfig CONFIG_LFS
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS silentoldconfig
    fi

    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS all

    # libbusybox.a
    "${GCC_LINUX_TARGET_PREFIX}ar" rcs "$MODULE_OUT/libbusybox.a"  $(find "$MODULE_OUT" -name "*.o" | grep -v "/scripts/" | grep -v "built-in.o" | xargs)
    "${GCC_LINUX_TARGET_PREFIX}objcopy" --redefine-sym main=busybox_main "$MODULE_OUT/libbusybox.a"
    "${GCC_LINUX_TARGET_PREFIX}objcopy" --redefine-sym xmkstemp=busybox_xmkstemp "$MODULE_OUT/libbusybox.a"
}

CompileAndroidApp() {
    if [ ! -f "$MODULE_OUT/.config" ];then
        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS allnoconfig
        # general options
        EnableConfig CONFIG_STATIC
        EnableConfig CONFIG_BUSYBOX
        EnableConfig CONFIG_SHOW_USAGE
        EnableConfig CONFIG_FEATURE_VERBOSE_USAGE
        EnableConfig CONFIG_FEATURE_COMPRESS_USAGE

        # misc utils
        EnableConfig CONFIG_ID
        EnableConfig CONFIG_CAT
        EnableConfig CONFIG_BLOCKDEV
        EnableConfig CONFIG_UNZIP
        EnableConfig CONFIG_CHMOD
        EnableConfig CONFIG_KILL
        EnableConfig CONFIG_BASE64
        EnableConfig CONFIG_RM

        # blkid
        EnableConfig CONFIG_BLKID
        EnableConfig CONFIG_FEATURE_BLKID_TYPE
        EnableConfig CONFIG_FEATURE_VOLUMEID_BCACHE
        EnableConfig CONFIG_FEATURE_VOLUMEID_BTRFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_CRAMFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_EXFAT
        EnableConfig CONFIG_FEATURE_VOLUMEID_EXT
        EnableConfig CONFIG_FEATURE_VOLUMEID_F2FS
        EnableConfig CONFIG_FEATURE_VOLUMEID_FAT
        EnableConfig CONFIG_FEATURE_VOLUMEID_HFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_ISO9660
        EnableConfig CONFIG_FEATURE_VOLUMEID_JFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_LINUXRAID
        EnableConfig CONFIG_FEATURE_VOLUMEID_LINUXSWAP
        EnableConfig CONFIG_FEATURE_VOLUMEID_LUKS
        EnableConfig CONFIG_FEATURE_VOLUMEID_NILFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_NTFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_OCFS2
        EnableConfig CONFIG_FEATURE_VOLUMEID_REISERFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_ROMFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_SQUASHFS
        EnableConfig CONFIG_FEATURE_VOLUMEID_SYSV
        EnableConfig CONFIG_FEATURE_VOLUMEID_UDF
        EnableConfig CONFIG_FEATURE_VOLUMEID_XFS

        # stat
        EnableConfig CONFIG_STAT
        EnableConfig CONFIG_FEATURE_STAT_FORMAT
        EnableConfig CONFIG_FEATURE_STAT_FILESYSTEM

        # find
        EnableConfig CONFIG_FIND
        EnableConfig CONFIG_FEATURE_FIND_PRINT0
        EnableConfig CONFIG_FEATURE_FIND_MTIME
        EnableConfig CONFIG_FEATURE_FIND_MMIN
        EnableConfig CONFIG_FEATURE_FIND_PERM
        EnableConfig CONFIG_FEATURE_FIND_TYPE
        EnableConfig CONFIG_FEATURE_FIND_XDEV
        EnableConfig CONFIG_FEATURE_FIND_MAXDEPTH
        EnableConfig CONFIG_FEATURE_FIND_NEWER
        EnableConfig CONFIG_FEATURE_FIND_INUM
        EnableConfig CONFIG_FEATURE_FIND_EXEC
        EnableConfig CONFIG_FEATURE_FIND_EXEC_PLUS
        EnableConfig CONFIG_FEATURE_FIND_USER
        EnableConfig CONFIG_FEATURE_FIND_GROUP
        EnableConfig CONFIG_FEATURE_FIND_NOT
        EnableConfig CONFIG_FEATURE_FIND_DEPTH
        EnableConfig CONFIG_FEATURE_FIND_PAREN
        EnableConfig CONFIG_FEATURE_FIND_SIZE
        EnableConfig CONFIG_FEATURE_FIND_PRUNE
        EnableConfig CONFIG_FEATURE_FIND_DELETE
        EnableConfig CONFIG_FEATURE_FIND_PATH
        EnableConfig CONFIG_FEATURE_FIND_REGEX
        EnableConfig CONFIG_FEATURE_FIND_CONTEXT
        EnableConfig CONFIG_FEATURE_FIND_LINKS

        # mkdir
        EnableConfig CONFIG_MKDIR
        EnableConfig CONFIG_FEATURE_MKDIR_LONG_OPTIONS

        # dd
        EnableConfig CONFIG_DD
        EnableConfig CONFIG_FEATURE_DD_SIGNAL_HANDLING
        EnableConfig CONFIG_FEATURE_DD_THIRD_STATUS_LINE
        EnableConfig CONFIG_FEATURE_DD_IBS_OBS
        EnableConfig CONFIG_FEATURE_DD_STATUS

        # ls
        EnableConfig CONFIG_LS
        EnableConfig CONFIG_FEATURE_LS_FILETYPES
        EnableConfig CONFIG_FEATURE_LS_FOLLOWLINKS
        EnableConfig CONFIG_FEATURE_LS_RECURSIVE
        EnableConfig CONFIG_FEATURE_LS_SORTFILES
        EnableConfig CONFIG_FEATURE_LS_TIMESTAMPS
        EnableConfig CONFIG_FEATURE_LS_USERNAME
        EnableConfig CONFIG_FEATURE_LS_COLOR
        EnableConfig CONFIG_FEATURE_LS_COLOR_IS_DEFAULT

        # ash
        EnableConfig CONFIG_ASH
        EnableConfig CONFIG_ASH_BASH_COMPAT
        EnableConfig CONFIG_ASH_IDLE_TIMEOUT
        EnableConfig CONFIG_ASH_JOB_CONTROL
        EnableConfig CONFIG_ASH_ALIAS
        EnableConfig CONFIG_ASH_GETOPTS
        EnableConfig CONFIG_ASH_BUILTIN_ECHO
        EnableConfig CONFIG_ASH_BUILTIN_PRINTF
        EnableConfig CONFIG_ASH_BUILTIN_TEST
        EnableConfig CONFIG_ASH_HELP
        EnableConfig CONFIG_ASH_CMDCMD
        EnableConfig CONFIG_ASH_MAIL
        EnableConfig CONFIG_ASH_OPTIMIZE_FOR_SIZE
        EnableConfig CONFIG_ASH_RANDOM_SUPPORT
        EnableConfig CONFIG_ASH_EXPAND_PRMT
        DisableConfig CONFIG_FEATURE_SH_IS_NONE
        EnableConfig CONFIG_FEATURE_SH_IS_ASH

        # mount
        EnableConfig CONFIG_MOUNT
        EnableConfig CONFIG_FEATURE_MOUNT_FAKE
        EnableConfig CONFIG_FEATURE_MOUNT_VERBOSE
        EnableConfig CONFIG_FEATURE_MOUNT_HELPERS
        EnableConfig CONFIG_FEATURE_MOUNT_LABEL
        EnableConfig CONFIG_FEATURE_MOUNT_NFS
        EnableConfig CONFIG_FEATURE_MOUNT_CIFS
        EnableConfig CONFIG_FEATURE_MOUNT_FLAGS
        EnableConfig CONFIG_FEATURE_MOUNT_FSTAB
        EnableConfig CONFIG_FEATURE_MOUNT_OTHERTAB

        # cp
        EnableConfig CONFIG_CP
        EnableConfig CONFIG_FEATURE_CP_LONG_OPTIONS

        "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS silentoldconfig
    fi

    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS all
}

Clean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS clean
}

DistClean() {
    "$MAKEFORWARD" "$EFIDROID_MAKE" -C "$MODULE_DIR" $BB_ARGS distclean
}
