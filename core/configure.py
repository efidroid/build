#!/usr/bin/env python
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

import glob
import hashlib
import urllib
from urlparse import urlparse
from utils import *
from buildlib import *

def getTargetName(args):
    if ('noprefix' in args.opts) and (args.opts['noprefix']=='1'):
        return args.targetname
    else:
        return args.clazz+'_'+args.targetname

def loadArgs2Target(target, args, nodeps=False, nohelp=False):
    target.source = args.filename
    target.clazz = args.clazz
    if args.moduledir:
        target.vars.set('MODULE_DIR', args.moduledir)
    target.vars.set('MODULE_NAME', args.targetname)
    target.vars.set('MODULE_CONFIG_DIR', args.moduleconfigdir)
    if 'outdir' in args.opts:
        target.vars.set('MODULE_OUT', '$(CLASS_OUT)/'+args.opts['outdir'])
    else:
        target.vars.set('MODULE_OUT', '$(CLASS_OUT)/$(MODULE_NAME)')
    if 'group' in args.opts:
        target.internal = args.opts['group']=='internal'
    if not nodeps:
        if 'dependencies' in args.opts:
            target.dependencies = args.opts['dependencies'].split()
    if not nohelp:
        if 'help' in args.opts:
            target.description = args.opts['help']

def parseSectionVariables(args):
    if len(args.attributes)>0:
        if args.attributes[0]=='uefi':
            space = args.context.uefivars
        else:
            raise Exception('invalid variable attributes: %s' % str(args.attributes))
    elif args.context.extdata.use_device_variable_space:
        space = args.context.clazzvars['device']
    else:
        space = args.context.globalvars

    for (name, value) in args.items:
        if name=='DEVICE_ARCHITECTURES':
            args.context.defaultarchitectures = value.split()
            continue
        space.set(name, value)

def parseSectionToolchain(args):
    toolchain = Toolchain(args.attributes, args.items)
    toolchain.source = args.filename
    args.context.addToolchain(toolchain)

def parseSectionLibrary(args):
    args.context.extdata.libraries.append(args)

def parseSectionUefiRd(args):
    moduleclazzes = ['device']

    if not 'device' in args.context.clazzes:
        return

    # get variables
    source = args.config.get(args.section, 'source')
    destination = args.config.get(args.section, 'destination')
    destination_abs = '$(LOCAL_UEFIRD_OUT)/ramdisk/'+destination
    destination_dirname = os.path.dirname(os.path.normpath(destination_abs))
    if args.config.has_option(args.section, 'dependencies'):
        args.opts['dependencies'] = args.config.get(args.section, 'dependencies')
    if args.config.has_option(args.section, 'moduleclasses'):
        moduleclazzes = args.config.get(args.section, 'moduleclasses').split()

    for clazz in moduleclazzes:
        if not clazz in args.context.clazzes:
            continue

        # build target
        target = Target()
        target.name = 'uefird_'+args.attributes[0]
        args.clazz = clazz
        args.targetname = target.name
        loadArgs2Target(target, args)
        target.force = True
        target.internal = True

        if clazz=='target':
            for arch in args.context.architectures:
                args.context.extdata.uefird_deps.append({'name':arch+'_'+target.name, 'target':target})
        else:
            args.context.extdata.uefird_deps.append({'name':target.name, 'target':target})
            if clazz=='device':
                target.vars.set('MODULE_ARCH', args.context.architectures[0])

        target.commands = [
            ['mkdir', '-p', '$(LOCAL_UEFIRD_OUT)/ramdisk'],
            ['mkdir', '-p', destination_dirname],
            [Target.Raw(
                'if [ -d "'+source+'" ];then '+
                    'cp -R '+source+' '+destination_dirname+';'+
                'else '+
                    'cp '+source+' '+destination_abs+';'+
                'fi'
            )]
        ]

        args.context.addTarget(target)

def parseModuleCmake(args):
    targetname = getTargetName(args)

    target = Target()
    target.name = targetname
    loadArgs2Target(target, args)
    target.force = True
    target.create_moduledir = True
    if not target.description:
        target.description = 'CMake target'

    # use target compiler
    cmakeargs = []
    if args.clazz in ['target', 'device']:
        cmakeargs.append('-DCMAKE_C_COMPILER=$(GCC_LINUX_TARGET_PREFIX)gcc')
        cmakeargs.append('-DCMAKE_CXX_COMPILER=$(GCC_LINUX_TARGET_PREFIX)g++')
        cmakeargs.append('-DCMAKE_LINKER=$(GCC_LINUX_TARGET_PREFIX)ld')
        cmakeargs.append('-DCMAKE_OBJCOPY=$(GCC_LINUX_TARGET_PREFIX)objcopy')
        cmakeargs.append('-DCMAKE_EXE_LINKER_FLAGS="-static"')

    # use our toolchain file for libraries and variables
    cmakeargs.append('-DCMAKE_TOOLCHAIN_FILE=$(CLASS_OUT)/toolchain.cmake')

    target.commands = [
        ['cd', '$(MODULE_OUT)', '&&', Target.COMMAND_ENV, 'cmake'] + cmakeargs + ['$(MODULE_CONFIG_DIR)'],
        [Target.COMMAND_MAKE, '-C', '$(MODULE_OUT)'],
    ]

    args.context.addTarget(target)

    # clean target
    target = Target()
    target.name = targetname+'_clean'
    loadArgs2Target(target, args, nohelp=True, nodeps=True)
    target.force = True
    target.internal = True
    target.commands = [
        [Target.Raw('[ -f \"$(MODULE_OUT)/Makefile\" ]'), '&&', '(',
            'cd', '$(MODULE_OUT)', ';', Target.COMMAND_MAKE, 'clean',
        ')', '||', 'true'],
    ]
    args.context.addTarget(target)
    args.context.cleantargets.append(target.name)

    # distclean target
    target = Target()
    target.name = targetname+'_distclean'
    loadArgs2Target(target, args, nohelp=True, nodeps=True)
    target.force = True
    target.internal = True
    target.dependencies.append(targetname+'_clean')
    target.commands = [
        [Target.Raw('[ -f \"$(MODULE_OUT)/Makefile\" ]'), '&&', '(',
            'cd', '$(MODULE_OUT)', ';', Target.COMMAND_MAKE, 'distclean',
        ')', '||', 'true'],
    ]
    args.context.addTarget(target)
    args.context.distcleantargets.append(target.name)

def parseModuleAutoconf(args):
    configureenv = ''
    makeenv = ''
    configureflags = ''
    generatorflags = ''
    maketargets = []
    linksource = False
    preparedir = args.moduledir
    generatorname = os.path.basename(os.path.normpath(args.filename))
    has_configure = generatorname=='configure'
    targetname = getTargetName(args)

    # get variables
    if 'maketargets' in args.opts:
        maketargets = args.opts['maketargets'].split()
    if 'configureenv' in args.opts:
        configureenv = args.opts['configureenv']
    if 'makeenv' in args.opts:
        makeenv = args.opts['makeenv']
    if 'configureflags' in args.opts:
        configureflags = args.opts['configureflags']
    if 'generatorflags' in args.opts:
        generatorflags = args.opts['generatorflags']
    if 'linksource' in args.opts:
        linksource = args.opts['linksource']=='1'
        preparedir = '$(MODULE_OUT)'

    # generate arguments
    generic_env = []
    if args.clazz in ['target', 'device']:
        # set tools
        generic_env.append('CC="$(GCC_LINUX_TARGET_PREFIX)gcc"')
        generic_env.append('CXX="$(GCC_LINUX_TARGET_PREFIX)g++"')
        configureflags += ' --host $(GCC_LINUX_TARGET_NAME)'
        configureenv += ' PATH="$(GCC_LINUX_TARGET_PATH):$$PATH"'
        makeenv += ' PATH="$(GCC_LINUX_TARGET_PATH):$$PATH"'

        # remove host directories
        generic_env.append('PKG_CONFIG_DIR=')
        generic_env.append('PKG_CONFIG_LIBDIR=')
        generic_env.append('PKG_CONFIG_SYSROOT_DIR=')
    configureenv += ' '+(' '.join(generic_env))
    makeenv += ' '+(' '.join(generic_env))

    # lns target
    if linksource:
        target = Target()
        target.name = '$(MODULE_OUT)/'+generatorname
        loadArgs2Target(target, args, nohelp=True, nodeps=True)
        target.internal = True
        target.compilationmessage = 'running lns on target \''+targetname+'\''
        target.commands = [
            ['rm', '-Rf', '$(MODULE_OUT)'],
            ['$(TOP)/build/tools/lns', '-rf', '$(MODULE_DIR)', '$(MODULE_OUT)'],
        ]

        if 'postlinkscript' in args.opts:
            target.commands += [
                [Target.COMMAND_ENV, '$(TOP)/build/tools/runscript', '$(CLASS_OUT)/config', '$(MODULE_CONFIG_DIR)/'+args.opts['postlinkscript'], 'PostLink'],
            ]

        args.context.addTarget(target)
    

    # generator target
    if not has_configure:
        target = Target()
        target.name = preparedir+'/configure'
        loadArgs2Target(target, args, nohelp=True, nodeps=True)
        target.internal = True
        target.compilationmessage = 'Autoconfiguring target \''+targetname+'\''
        target.dependencies.append(preparedir+'/'+generatorname)
        target.commands = [
            ['cd', preparedir, '&&', './'+generatorname, Target.Raw(generatorflags)],
        ]
        args.context.addTarget(target)

    # configure target
    target = Target()
    target.name = '$(MODULE_OUT)/Makefile'
    loadArgs2Target(target, args, nohelp=True, nodeps=True)
    target.internal = True
    target.compilationmessage = 'Configuring target \''+targetname+'\''
    target.dependencies.append(preparedir+'/configure')
    target.create_moduledir = True
    target.commands = [
        ['cd', '$(MODULE_OUT)', '&&', Target.COMMAND_ENV, Target.Raw(configureenv), preparedir+'/configure', Target.Raw(configureflags)],
    ]
    args.context.addTarget(target)

    # main target
    target = Target()
    target.name = targetname
    loadArgs2Target(target, args)
    target.force = True
    target.dependencies.append('$(MODULE_OUT)/Makefile')
    if not target.description:
        target.description = 'autoconf target'
    target.commands = [
        ['cd', '$(MODULE_OUT)', '&&', Target.COMMAND_ENV, Target.Raw(makeenv), Target.COMMAND_MAKE] + maketargets,
    ]
    args.context.addTarget(target)

    # clean target
    target = Target()
    target.name = targetname+'_clean'
    loadArgs2Target(target, args, nohelp=True, nodeps=True)
    target.force = True
    target.internal = True
    target.commands = [
        [Target.Raw('[ -f \"$(MODULE_OUT)/Makefile\" ]'), '&&', '(',
            'cd', '$(MODULE_OUT)', ';', Target.COMMAND_MAKE, 'clean',
        ')', '||', 'true'],
    ]
    args.context.addTarget(target)
    args.context.cleantargets.append(target.name)

    # distclean target
    target = Target()
    target.name = targetname+'_distclean'
    loadArgs2Target(target, args, nohelp=True, nodeps=True)
    target.force = True
    target.internal = True
    target.dependencies.append(targetname+'_clean')
    target.commands = [
        [Target.Raw('[ -f \"$(MODULE_OUT)/Makefile\" ]'), '&&', '(',
            'cd', '$(MODULE_OUT)', ';', Target.COMMAND_MAKE, 'distclean',
        ')', '||', 'true'],
    ]
    args.context.addTarget(target)
    args.context.distcleantargets.append(target.name)

def parseModuleMake(args):
    pr_warning('Makefile targets are not yet supported (%s)' % args.context.striptopdir(args.moduleconfigdir))
    #print('make:', args.targetname)
    #print(args.moduledir, args.filename, args.targetname)
    pass

def parseModuleUefiApp(args):
    args.targetname = 'uefiapp_'+args.targetname
    args.opts['noprefix'] = '1'
    args.opts['scriptfile'] = 'edk2-appbase.sh'
    args.opts['compilefunction'] = 'CompileApp'
    if not 'dependencies' in args.opts:
        args.opts['dependencies'] = ''
    args.opts['dependencies'] += ' edk2_basetools'
    args.moduleconfigdir = '$(TOP)/build/core/tasks'
    return parseModuleScript(args)

def parseModuleScript(args):
    targetname = getTargetName(args)
    arr_compilefn = [args.opts['compilefunction'], 'Clean', 'DistClean']
    arr_suffix = ['', '_clean', '_distclean']
    arr_deps = [None, '', targetname+'_clean']
    
    for i in range(3):
        compilefn = arr_compilefn[i]
        suffix = arr_suffix[i]
        deps = arr_deps[i]

        target = Target()
        target.name = targetname + suffix
        loadArgs2Target(target, args, nohelp=i>0, nodeps=i>0)
        target.force = True
        target.create_moduledir = True
        if i > 0:
            target.internal = True
        if not target.description:
            target.description = 'script target'
        if deps:
            target.dependencies = deps.split()

        path_scriptfile = '$(MODULE_CONFIG_DIR)/'+args.opts['scriptfile']
        path_config = '$(CLASS_OUT)/config'
        target.commands = [
            [Target.COMMAND_ENV, '$(TOP)/build/tools/runscript', path_config, path_scriptfile, compilefn],
        ]

        args.context.addTarget(target)

    args.context.cleantargets.append(targetname+'_clean')
    args.context.distcleantargets.append(targetname+'_clean')

def load_fstab(context, deviceid):
    # parse fstab
    path_device_fstab = 'device/'+deviceid+'/fstab.multiboot'
    if not os.path.isfile(path_device_fstab):
        raise Exception('fstab.multiboot does not exist')
    fstab = FSTab(path_device_fstab)

    # get nvvars partition
    nvvarspart = fstab.getNVVarsPartition();
    if not nvvarspart:
        raise Exception('fstab doesn\'t have a nvvars partition')

    # check if there's an esp partition
    esppart = fstab.getESPPartition()
    if not esppart:
        raise Exception('fstab doesn\'t have a esp partition')

    # get uefi partitions
    uefiparts = fstab.getUEFIPartitionNameList()
    if len(uefiparts) < 1:
        raise Exception('fstab doesn\'t have any uefi partitions')

    # set variables
    context.clazzvars['device'].set('DEVICE_FSTAB', 'device/'+deviceid+'/fstab.multiboot')
    context.clazzvars['device'].set('DEVICE_NVVARS_PARTITION', nvvarspart)
    context.clazzvars['device'].set('DEVICE_NVVARS_PARTITION_LK', fstab.partitionpath2name(nvvarspart))
    context.clazzvars['device'].set('DEVICE_UEFI_PARTITIONS', ' '.join(uefiparts))

def genvarinc(prefix, spaces, evalvars):
    mk_sio = StringIO()
    mk_writer = make_syntax.Writer(mk_sio, nodefaulttarget=True)
    f_sh = open(prefix+'.sh', 'w')
    f_py = open(prefix+'.py', 'w')
    f_cmake = open(prefix+'.cmake', 'w')

    for space in spaces:
        for name in space.vars:
            if name.endswith('_CLASS_OUT'):
                continue
            if name.endswith('LOCAL_UEFIRD_OUT'):
                continue

            value = space.vars[name]
            for o in evalvars:
                value = o.evaluate_str(value)
            VariableSpace.verify(value)

            # make
            mk_writer.variable(name, value.replace('$', '$$'))
            # shell
            f_sh.write('export '+name+'=\''+value.replace('$', '\$').replace('\'', '\\\'')+'\'\n')
            # python
            f_py.write(name+'=\''+value.replace('\'', '\\\'')+'\'\n')
            # cmake
            f_cmake.write('set('+name+' "'+value.replace('"', '\\"')+'")\n')

    f_cmake.close()
    f_py.close()
    f_sh.close()

    with open(prefix+'.mk', 'w') as f:
        f.write(mk_sio.getvalue())
    mk_writer.close()

def create_uefird_target(context):
    target = Target()
    target.name = 'uefird'
    target.clazz = 'device'
    target.internal = True
    target.phony = True
    target.create_moduledir = True
    target.dependencies = [o['name'] for o in context.extdata.uefird_deps]
    target.vars.set('MODULE_ARCH', context.architectures[0])
    target.vars.set('MODULE_OUT', '$(DEVICE_OUT)/uefird')

    target.commands = [
        ['mkdir', '-p', '$(UEFIRD_OUT)/ramdisk'],
        ['cd', '$(UEFIRD_OUT)/ramdisk', '&&', Target.Raw('find . | cpio -o -H newc > $(UEFIRD_CPIO)')],
    ]

    context.addTarget(target)

    # add uefird variables
    module_out = context.clazzvars['device'].evaluate_str(target.vars.get('MODULE_OUT'))
    context.clazzvars['device'].set('UEFIRD_OUT', module_out)
    context.clazzvars['device'].set('UEFIRD_CPIO', '$(UEFIRD_OUT)/ramdisk.cpio')

    for depentry in context.extdata.uefird_deps:
        depentry['target'].vars.set('LOCAL_UEFIRD_OUT', module_out)

def toolchain_write_header(context, f, dirname):
    f.write('if(DEFINED CMAKE_TOOLCHAIN_READY)\n')
    f.write('\treturn()\n')
    f.write('endif()\n\n')

    f.write('include("'+dirname+'/config.cmake")\n\n')

def toolchain_write_library(context, f, target, args):
    # get variables
    includes = []
    libname = args.attributes[0]
    filename = args.config.get(args.section, 'file')
    if args.config.has_option(args.section, 'includes'):
        includes += args.config.get(args.section, 'includes').split()
    if args.config.has_option(args.section, 'name'):
        libname = args.config.get(args.section, 'name')

    # build includes string
    inlcudesstr = ''
    for include in includes:
        inlcudesstr += ' \"'+include+'\"'

    # expand variables
    filename = context.expandVariables(target, filename)
    inlcudesstr = context.expandVariables(target, inlcudesstr)
    VariableSpace.verify(filename)
    VariableSpace.verify(inlcudesstr)

    # write to toolchain file
    f.write('if(NOT "$ENV{MODULE_NAME}" STREQUAL "'+target.vars.get('MODULE_NAME')+'")\n')
    f.write('add_library("'+libname+'" STATIC IMPORTED)\n')
    f.write('set_target_properties('+libname+' PROPERTIES IMPORTED_LOCATION '+ filename +')\n')
    if len(inlcudesstr)>0:
        f.write('include_directories('+inlcudesstr+')\n')
    f.write('endif()\n\n')
    f.write('\n')

def gen_toolchains(context):
    files = {}

    # open files and write headers
    for clazz in context.clazzvars:
        clazzvars = context.clazzvars[clazz]
        dirname = context.getfname(clazzvars.get(clazz.upper()+'_OUT'), absolute=True, otherspaces=[clazzvars])

        f = open(dirname+'/toolchain.cmake', 'w')
        files[clazz] = f
        toolchain_write_header(context, f, dirname)

    # write contents
    for args in context.extdata.libraries:
        targetname = args.config.get(args.section, 'target')
        for name in [c+'_'+targetname for c in context.clazzes] + [targetname]:
            target = context.getTarget(name)
            if not target:
                continue

            # aliased targets need per-arch toolchains
            if target.is_archalias:
                for arch in context.architectures:
                    archname = arch+'_'+name
                    target = context.getTarget(archname)
                    if not target:
                        raise Exception('aliased target \''+archname+'\' doesn\'t exist')
                    toolchain_write_library(context, files[target.clazz+'_'+arch], target, args)

                    # device targets can use 'target' class libraries too
                    if 'device' in context.clazzes and target.clazz=='target' and arch==context.architectures[0]:
                        toolchain_write_library(context, files['device'], target, args)

            # everyone elses uses one toolchain per class
            else:
                toolchain_write_library(context, files[target.clazz], target, args)

    # write file footers
    for clazz in files:
        f = files[clazz]
        f.write('# prevent multiple inclusion\n')
        f.write('set(CMAKE_TOOLCHAIN_READY TRUE)\n')
        f.close()

def sha1(filepath):
    sha1lib = hashlib.sha1()

    with open(filepath, 'rb') as f:
        sha1lib.update(f.read())

    return sha1lib.hexdigest()

def setup_toolchain(context, toolchain):
    toolchain_path = toolchain.localvars.get('path', throw=False)
    toolchain_src = toolchain.localvars.get('src', throw=False)
    toolchain_sha1 = toolchain.localvars.get('sha1', throw=False)

    # this toolchain doesn't provide a directory(it's native)
    if toolchain_path:
        toolchain_path = context.getfname(toolchain_path, absolute=True)
    if not toolchain_path:
        return

    # stop if toolchain dir does already exist
    if os.path.isdir(toolchain_path):
        return

    # check if we have a source
    if toolchain_src:
        toolchain_src = context.getfname(toolchain_src, absolute=True)
    if not toolchain_src:
        raise Exception('Toolchain in \''+toolchain_path+'\' doesn\'t exist and has no source option')

    # make cachedir
    cachedir = 'prebuilts/cache'
    try:
        os.makedirs(cachedir)
    except:
        pass

    # download toolchain
    filename = urllib.unquote(os.path.basename(urlparse(toolchain_src).path))
    downloadfile = cachedir+'/'+filename
    if not os.path.isfile(downloadfile) or not sha1(downloadfile)==toolchain_sha1:
        pr_alert('Downloading toolhain \'%s\' ...' % filename)
        p = subprocess.Popen(['curl', '-L', '-o', downloadfile, toolchain_src])
        p.communicate()
        if p.returncode:
            pr_fatal('Can\'t download toolchain')

        # verify checksum
        if not sha1(downloadfile)==toolchain_sha1:
            pr_fatal('sha1sum doesn\'t match')

    # make toolchain dir
    gcc_target_dir = context.getfname('$(GCC_DIR)/'+toolchain.arch, absolute=True)
    try:
        os.makedirs(gcc_target_dir)
    except:
        pass

    # extract toolchain
    pr_alert('extracting '+downloadfile+' ...')
    p = subprocess.Popen(['tar', 'xf', downloadfile, '-C', gcc_target_dir])
    p.communicate()
    if p.returncode:
        pr_fatal('Can\'t extract toolchain')

    if not os.path.isdir(toolchain_path):
        pr_fatal('invalid toolchain')

def main(argv):
    context = Context()
    context.iniparser.registerSectionHandler('variables', parseSectionVariables)
    context.iniparser.registerSectionHandler('toolchain', parseSectionToolchain)
    context.iniparser.registerSectionHandler('library', parseSectionLibrary)
    context.iniparser.registerSectionHandler('uefird', parseSectionUefiRd)
    context.moduleparser.registerModuleHandler('cmake', parseModuleCmake)
    context.moduleparser.registerModuleHandler('autoconf', parseModuleAutoconf)
    context.moduleparser.registerModuleHandler('make', parseModuleMake)
    context.moduleparser.registerModuleHandler('uefiapp', parseModuleUefiApp)
    context.moduleparser.registerModuleHandler('script', parseModuleScript)
    context.extdata.uefird_deps = []
    context.extdata.libraries = []
    context.extdata.use_device_variable_space = False

    # parse basic config
    context.iniparser.parseFile('build/config.ini')

    # set device variables
    deviceid = None
    if 'device' in context.clazzes:
        deviceid = context.clazzvars['device'].get('DEVICE')
        load_fstab(context, deviceid)
        context.extdata.use_device_variable_space = True
        context.iniparser.parseFile('device/'+deviceid+'/config.ini')
        context.extdata.use_device_variable_space = False

    # enable architectures
    for arch in context.defaultarchitectures:
        context.enableArch(arch)

    if len(context.defaultarchitectures)>0:
        context.enableClazz('target')

    # expand filenames before the variable space gets too big
    path_top = context.getfname('$(TOP)', absolute=True)
    path_out = context.getfname('$(OUT)', absolute=True)

    # parse tasks
    for inifile in glob.glob(path_top+'/build/core/tasks/*.ini'):
        context.iniparser.parseFile(inifile)

    # parse modules
    path_moduleconfigs = path_top+'/build/moduleconfigs'
    for moduledir in glob.glob(path_top+'/modules/*'):
        context.moduleparser.parseModule(moduledir, path_moduleconfigs)

    # parse uefi apps
    path_uefiappconfigs = path_top+'/build/uefiappconfigs'
    for moduledir in glob.glob(path_top+'/uefi/apps/*'):
        context.moduleparser.parseModule(moduledir, path_uefiappconfigs)

    if 'device' in context.clazzes:
        create_uefird_target(context)

    # print information
    pr_alert('Buildtype: '+context.globalvars.get('BUILDTYPE'))
    if deviceid:
        pr_alert('Device: %s' % deviceid)
    pr_alert('Architectures: %s' % (', '.join(context.architectures)))
    pr_alert('Configuring for %s' % (', '.join(context.clazzes)))

    for arch in context.architectures:
        toolchains = context.findToolchains(arch);
        for toolchain in toolchains:
            for name in toolchain.toolchainvars.vars:
                context.globalvars.set('TOOLCHAIN_'+arch.upper()+'_'+name, toolchain.toolchainvars.vars[name])

    # generate uefi commandline
    if 'device' in context.clazzes:
        cmdline = ''
        for name in context.uefivars.vars:
            value = context.uefivars.vars[name]
            cmdline += ' -D'+name+'="'+value+'"'

        context.clazzvars['device'].set('UEFI_VARIABLES_CMDLINE', cmdline)

    # create out directory
    try:
        os.makedirs(path_out)
    except:
        pass

    # prepare things
    context.prepare_targets()
    context.prepare_dependencies()
    context.create_target_variables()

    # generate config files
    for clazz in context.clazzvars:
        spaces = []
        clazzvars = context.clazzvars[clazz]

        dirname = context.getfname(clazzvars.get(clazz.upper()+'_OUT'), absolute=True, otherspaces=[clazzvars])
        try:
            os.makedirs(dirname)
        except:
            pass

        spaces.append(clazzvars)
        if clazz=='device':
            spaces.append(context.clazzvars['target_'+context.architectures[0]])
        if clazz!='host':
            spaces.append(context.clazzvars['host'])
        spaces.append(context.globalvars)

        localspace = VariableSpace()
        localspace.set('EFIDROID_CONFIG_PATH', dirname+'/config')
        spaces.append(localspace)

        genvarinc(dirname+'/config', spaces, spaces)

    # generate toolchains
    gen_toolchains(context)

    # generate makefile
    context.generate_makefile(path_out+'/build.mk');

    # toolchain setup
    for toolchain in context.toolchains_used:
        setup_toolchain(context, toolchain)

if __name__ == "__main__":
    runmain(main)
