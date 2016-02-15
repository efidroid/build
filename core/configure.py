#!/usr/bin/python -B

# common imports
import os.path
import sys
import glob
import make_syntax
import os
import subprocess
import os
from fstab import *
from utils import *

# compatibility imports
try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

try:
    import ConfigParser
except ImportError:
    import configparser as ConfigParser

def setvar(name, value):
    cfg.variables[name] = value

def expandvars(string):
    # all variables got expanded already so this is much easier
    for k, v in cfg.variables.items():
        string = string.replace('$(%s)' % k, v)

    return string

def expandmodulevars(string, module, projecttype):
    module_out = getvar(projecttype.upper()+'_'+module.upper()+'_OUT')
    module_src = getvar(projecttype.upper()+'_'+module.upper()+'_SRC')

    if module_out and module_src:
        string = string.replace('$(%s)' % 'MODULE_OUT', module_out)
        string = string.replace('$(%s)' % 'MODULE_SRC', module_src)
        return string

    return None

def evaluatevars():
    # replace variables
    processed = 1
    while processed > 0:
        processed = 0
        for name, value in cfg.variables.items():
            parsedvalue = cfg.variables[name]
            for k, v in cfg.variables.items():
                parsedvalue = parsedvalue.replace('$(%s)' % k, v)

                if parsedvalue != cfg.variables[name]:
                    # detect recursion
                    if '$('+name+')' in parsedvalue:
                        raise Exception('Variable \''+name+'\' depends on \''+k+'\' which depends on \''+name+'\' again')

                    cfg.variables[name] = parsedvalue
                    processed = processed+1

def genvarinc():
    evaluatevars()

    # generate variable files
    for name, value in cfg.variables.items():
        # make
        cfg.makevars.variable(name, value.replace('$', '$$'))
        # shell
        cfg.configinclude_sh.write('export '+name+'=\"'+value.replace('$', '\$')+'\"\n')
        # python
        cfg.configinclude_py.write(name+'=\''+value+'\'\n')
        # cmake
        cfg.configinclude_cmake.write('set('+name+' "'+value+'")\n')

def getvar(name):
    if name in cfg.variables:
        return cfg.variables[name]
    return None

def addhelp(name, text):
    cfg.helptext += bldwht.replace('\033', '\\033')+name+': '+txtrst.replace('\033', '\\033')+text.replace('\n', '\\n'+((len(name)+2)*' '))+'\\n'

def define_target_vars(name, projecttype, src):
    name_upper = name.upper()

    # set target variables            
    if projecttype=='target':
        setvar('TARGET_'+name_upper+'_OUT', getvar('TARGET_OUT')+'/'+name)
        setvar('TARGET_'+name_upper+'_SRC', src)
    elif projecttype=='host':
        setvar('HOST_'+name_upper+'_OUT', getvar('HOST_OUT')+'/'+name)
        setvar('HOST_'+name_upper+'_SRC', src)

def register_library(target, name, filename, includes, static=True):
    o = Bunch()
    o.target = target
    o.filename = filename
    o.includes = includes
    o.static = static

    cfg.libs[name] = o

def toolchain_write_header(f):
    f.write('if(DEFINED CMAKE_TOOLCHAIN_READY)\n')
    f.write('\treturn()\n')
    f.write('endif()\n\n')

    f.write('include("'+cfg.configinclude_name+'.cmake")\n\n')


def toolchain_write_footer(f):
    f.write('# prevent multiple inclusion\n')
    f.write('set(CMAKE_TOOLCHAIN_READY TRUE)\n')
    
def gen_toolchains():

    if not os.path.isdir(getvar('HOST_OUT')):
        os.makedirs(getvar('HOST_OUT'))
    fHost   = open(getvar('HOST_OUT')+'/toolchain.cmake', 'w')
    toolchain_write_header(fHost)

    if cfg.devicename:
        if not os.path.isdir(getvar('TARGET_OUT')):
            os.makedirs(getvar('TARGET_OUT'))

        fTarget = open(getvar('TARGET_OUT')+'/toolchain.cmake', 'w')
        toolchain_write_header(fTarget)

    for name, o in cfg.libs.items():
        linkage = 'STATIC'
        if not o.static:
            linkage = 'SHARED'

        inlcudesstr = ''
        for include in o.includes:
            inlcudesstr += ' \"'+include+'\"'

        inc_expanded = expandmodulevars(inlcudesstr, o.target, 'host')
        file_expanded = expandmodulevars(o.filename, o.target, 'host')
        if not inc_expanded==None and not file_expanded==None:
            f = fHost
            f.write('if(NOT "${EFIDROID_TARGET}" STREQUAL "'+o.target+'")\n')
            f.write('add_library("'+name+'" '+linkage+' IMPORTED)\n')
            f.write('set_target_properties('+name+' PROPERTIES IMPORTED_LOCATION '+ expandvars(file_expanded)+')\n')
            if inc_expanded:
                f.write('include_directories('+inc_expanded+')\n')
            f.write('endif()\n\n')
            f.write('\n')

        if cfg.devicename:
            inc_expanded = expandmodulevars(inlcudesstr, o.target, 'target')
            file_expanded = expandmodulevars(o.filename, o.target, 'target')
            if not inc_expanded==None and not file_expanded==None:
                f = fTarget
                f.write('if(NOT "${EFIDROID_TARGET}" STREQUAL "'+o.target+'")\n')
                f.write('add_library("'+name+'" '+linkage+' IMPORTED)\n')
                f.write('set_target_properties('+name+' PROPERTIES IMPORTED_LOCATION '+ expandvars(file_expanded)+')\n')
                if inc_expanded:
                    f.write('include_directories('+inc_expanded+')\n')
                f.write('endif()\n\n')
                f.write('\n')

    if cfg.devicename:
        toolchain_write_footer(fTarget)
        fTarget.close()

    toolchain_write_footer(fHost)
    fHost.close()

def parse_config(configfile, moduledir=None):
    cfg.make.comment(configfile)

    config = ConfigParser.RawConfigParser(allow_no_value=True)
    config.optionxform = str
    config.read(configfile)

    for section in config.sections():
        if section == 'variables':
            for (name, value) in config.items(section):
                setvar(name, value)

        elif section.startswith('target.') or section.startswith('host.'):
            targetname = section.split('.', 1)[1]
            targetname_id = targetname.upper()
            targettype = config.get(section, 'type')
            targetrule = targetname+'_rule'
            targetdir  = os.path.abspath(os.path.dirname(configfile))
            targetdeps = []
            targetcompilefn = 'EFIDroidCompile'
            targetforcecompile = True
            targetcategory = section.split('.', 1)[0]
            targetout = None
            outdir = targetname
            maketargets = []
            configureenv = ''
            configureflags = ''
            linksource = False

            if not moduledir:
                moduledir = targetdir
            else:
                moduledir = os.path.abspath(moduledir)

            if config.has_option(section, 'dependencies'):
                targetdeps = targetdeps + config.get(section, 'dependencies').split()
            if config.has_option(section, 'compilefunction'):
                targetcompilefn = config.get(section, 'compilefunction')
            if config.has_option(section, 'forcecompile'):
                targetforcecompile = config.get(section, 'forcecompile')=='1'
            if config.has_option(section, 'category'):
                targetcategory = config.get(section, 'category')
            if config.has_option(section, 'subtargets'):
                subtargets = config.get(section, 'subtargets').split()
            if config.has_option(section, 'maketargets'):
                maketargets += config.get(section, 'maketargets').split()
            if config.has_option(section, 'configureenv'):
                configureenv += config.get(section, 'configureenv')
            if config.has_option(section, 'configureflags'):
                configureflags += config.get(section, 'configureflags')
            if config.has_option(section, 'linksource'):
                linksource = config.get(section, 'linksource')=='1'

            # validate category
            if not targetcategory=='target' and not targetcategory=='host':
                raise Exception('Invalid category \''+targetcategory+'\' in '+configfile)

            if targetforcecompile:
                targetdeps += ['FORCE']

            # skip device targets if we're building in host-only mode
            if not cfg.devicename and targetcategory=='target':
                continue

            if config.has_option(section, 'outdir'):
                outdir = config.get(section, 'outdir')

            if targetcategory=='target':
                targetout = getvar('TARGET_OUT')+'/'+outdir
            elif targetcategory=='host':
                targetout = getvar('HOST_OUT')+'/'+outdir

            # add rule
            command = ''
            if targettype == 'script':
                targetscriptfile = config.get(section, 'scriptfile')
                command = 'build/tools/runscript "'+\
                           cfg.out+'" "'+cfg.configinclude_name+'" "'+targetdir+'/'+targetscriptfile+'"'+\
                           ' "'+targetcategory+'" "'+targetname+'" "'+targetout+'" "'+moduledir+'"'

                # add build target
                make_add_target(configfile, targetname, command+' '+targetcompilefn, deps=targetdeps,\
                                description='Compiling target \''+targetname+'\'')

                # add clean target
                make_add_target(configfile, targetname+'_clean', command+' Clean', deps=['FORCE'],\
                                description='Cleaning target \''+targetname+'\'')
                cfg.make.dependencies('clean', targetname+'_clean')

                # add distclean target
                make_add_target(configfile, targetname+'_distclean', command+' DistClean',\
                                description='Dist-Cleaning target \''+targetname+'\'')
                cfg.make.dependencies('distclean', targetname+'_distclean')

                # add help entry
                if config.has_option(section, 'help'):
                    addhelp(targetname, config.get(section, 'help'))
                else:
                    addhelp(targetname, '\''+targetcategory+'/'+targettype+'\' target')

            elif targettype == 'autoconf':
                generator = None
                if os.path.isfile(moduledir+'/autogen.sh'):
                    generator = 'autogen.sh'
                elif os.path.isfile(moduledir+'/makeconf.sh'):
                    generator = 'makeconf.sh'
                elif os.path.isfile(moduledir+'/bootstrap'):
                    generator = 'bootstrap'
                elif os.path.isfile(moduledir+'/configure'):
                    generator = 'configure'
                else:
                    raise Exception('no generator found')

                compiledir = moduledir
                if linksource:
                    compiledir = targetout

                    # add lns target
                    make_add_target(configfile, targetout+'/'+generator, cfg.top+'/build/tools/lns -rf \"'+moduledir+'\" \"'+targetout+'\"',\
                                    description='runnin lns on target \''+targetname+'\'')

                # add autogen target
                if not generator=='configure':
                    make_add_target(configfile, compiledir+'/configure', 'cd \"'+compiledir+'\" && ./'+generator, deps=compiledir+'/'+generator,\
                                    description='Autoconfiguring target \''+targetname+'\'')

                # add configure target
                if targetcategory=='target':
                    configureflags += ' --host '+getvar('GCC_LINUX_TARGET_NAME')
                commands = [
                    'mkdir -p \"'+targetout+'\"',
                    'cd \"'+targetout+'\" && '+configureenv+' \"'+compiledir+'/configure\" '+configureflags
                ]
                make_add_target(configfile, targetout+'/Makefile', commands, deps=compiledir+'/configure',\
                                description='Configuring target \''+targetname+'\'')

                # add make target
                make_add_target(configfile, targetname, 'cd \"'+targetout+'\" && $(MAKE) '+(' '.join(maketargets)), \
                                deps=targetdeps+[targetout+'/Makefile'], description='Compiling target \''+targetname+'\'')

                # add clean target
                make_add_target(configfile, targetname+'_clean', '[ -f \"'+targetout+'\" ] && cd \"'+targetout+'\" && [ -f Makefile ] && $(MAKE) clean || true',\
                                deps=['FORCE'], description='Cleaning target \''+targetname+'\'')
                cfg.make.dependencies('clean', targetname+'_clean')

                # add distclean target
                make_add_target(configfile, targetname+'_distclean', '[ -f \"'+targetout+'\" ] && cd \"'+targetout+'\" && [ -f Makefile ] && $(MAKE) distclean || true', \
                                deps=[targetname+'_clean'], description='Dist-Cleaning target \''+targetname+'\'')
                cfg.make.dependencies('distclean', targetname+'_distclean')

                # add help entry
                if config.has_option(section, 'help'):
                    addhelp(targetname, config.get(section, 'help'))
                else:
                    addhelp(targetname, '\''+targetcategory+'/'+targettype+'\' target')

            elif targettype == 'cmake':
                add_cmake_target(os.path.dirname(configfile), targetcategory, moduledir, maketargets=maketargets, disableprefix=True)
                cfg.make.dependencies(targetname, targetdeps)

            elif targettype == 'command':
                command = expandvars(config.get(section, 'command'))
                 # add make target
                make_add_target(configfile, targetname, command, deps=targetdeps, description='Compiling target \''+targetname+'\'')

            else:
                raise Exception('Invalid target type \''+targettype+'\' in '+configfile)

            # set target variables            
            setvar(targetname_id+'_CONFIG_DIR', targetdir)
            define_target_vars(targetname, targetcategory, moduledir)

        elif section.startswith('library.'):
            libname = section.split('.', 1)[1]
            filename = config.get(section, 'file')
            target = config.get(section, 'target')

            includes = []
            if config.has_option(section, 'includes'):
                includes += config.get(section, 'includes').split()

            register_library(target, libname, filename, includes)

        elif section.startswith('uefird.'):
            idx = section.split('.', 1)[1]
            source = config.get(section, 'source').replace('$(%s)' % 'MODULE_SRC', cfg.top+'/'+moduledir)
            destination = config.get(section, 'destination')

            targetname = 'uefird_'+idx
            targetdeps = ['FORCE']

            if config.has_option(section, 'dependencies'):
                targetdeps = targetdeps + config.get(section, 'dependencies').split()

            make_add_target(configfile, targetname, [
                'mkdir -p $(UEFIRD_DIR)',
                'mkdir -p $$(dirname $(UEFIRD_DIR)/'+destination+')',
                'if [ -d "'+source+'" ];then '+
                    'cp -R '+source+' $$(dirname $(UEFIRD_DIR)/'+destination+');'+
                'else '+
                    'cp '+source+' $(UEFIRD_DIR)/'+destination+';'+
                'fi',
            ], deps=targetdeps, description='Compiling target \''+targetname+'\'')
            cfg.uefird_deps += [targetname]

        elif section == 'parseopts':
            pass

        else:
            raise Exception('Invalid section \''+section+'\' in '+configfile)

    cfg.make.newline()

def parse_deps(configfile):
    cfg.make.comment(configfile)

    config = ConfigParser.RawConfigParser(allow_no_value=True)
    config.optionxform = str
    config.read(configfile)

    for targetname in config.sections():
        for (name, value) in config.items(targetname):
            cfg.make.dependencies(targetname, name)

    cfg.make.newline()

def cfg_parse_opts(configfile):
    config = ConfigParser.RawConfigParser(allow_no_value=True)
    config.optionxform = str
    config.read(configfile)
    opts = {}

    for sectionname in config.sections():
        if sectionname == 'parseopts':
            for (name, value) in config.items(sectionname):
                opts[name] = value

    return opts

def add_cmake_target(path, projecttype, modulesrc=None, maketargets=None, disableprefix=False):
    cfg.make.comment(path)

    dirname = os.path.basename(os.path.normpath(path))
    if disableprefix:
        targetname = dirname
    else:
        targetname = projecttype+'_'+dirname
    targetdeps = ['FORCE']
    cmakeargs = ''

    if projecttype == 'target':
        # skip if we're in host mode
        if not cfg.devicename:
            return

        prefix = getvar('GCC_LINUX_TARGET_PREFIX')
        cmakeargs += ' -DCMAKE_C_COMPILER='+prefix+'gcc'
        cmakeargs += ' -DCMAKE_CXX_COMPILER='+prefix+'g++'
        cmakeargs += ' -DCMAKE_LINKER='+prefix+'ld'
        cmakeargs += ' -DCMAKE_OBJCOPY='+prefix+'objcopy'
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('TARGET_OUT')+'/toolchain.cmake'
    elif projecttype == 'host':
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('HOST_OUT')+'/toolchain.cmake'
    else:
        raise Exception('Invalid projecttype \''+projecttype+'\'')

    cmakeargs += ' -DEFIDROID_TARGET='+dirname

    if modulesrc:
        cmakeargs += ' -DMODULE_SRC='+os.path.abspath(modulesrc)

    define_target_vars(dirname, projecttype, os.path.abspath(path))

    # add rule
    outdir = getvar(projecttype.upper()+'_'+dirname.upper()+'_OUT')
    make_add_target(path, targetname, [
        'mkdir -p \"'+outdir+'\"',
        'cd \"'+outdir+'\" && cmake '+cmakeargs+' '+os.path.abspath(path)+' && $(MAKE)'
    ], description='Compiling target \''+targetname+'\'', deps=targetdeps)
    addhelp(targetname, 'CMake target')

    # add clean rule
    make_add_target(path, targetname+'_clean', [
        'cd \"'+outdir+'\" && $(MAKE) clean'
    ], description='Cleaning target \''+targetname+'\'', deps=['FORCE'])
    cfg.make.dependencies('clean', targetname+'_clean')

    # add distclean rule
    make_add_target(path, targetname+'_distclean', [
        'rm -Rf \"'+outdir+'\"'
    ], description='Dist-Cleaning target \''+targetname+'\'')
    cfg.make.dependencies('distclean', targetname+'_distclean')

    cfg.make.newline()

def add_uefiapp_target(path):
    cfg.make.comment(path)

    dirname = os.path.basename(os.path.normpath(path))
    targetname = 'uefiapp_'+dirname
    targetdeps = ['FORCE']

    scriptfile  = os.path.abspath('build/core/tasks/edk2-appbase.sh')
    targetout  = os.path.abspath('out/host/edk2_appbase')
    moduledir = os.path.abspath('build/core/tasks')
    targetcompilefn = 'CompileApp'
    command = 'UEFIAPP="'+cfg.top+'/'+path+'" build/tools/runscript "'+\
               cfg.out+'" "'+cfg.configinclude_name+'" "'+scriptfile+'"'+\
               ' "host" "edk2_appbase" "'+targetout+'" "'+moduledir+'"'

    # add build target
    make_add_target(path, targetname, command+' '+targetcompilefn, deps=targetdeps,\
                    description='Compiling target \''+targetname+'\'')
    addhelp(targetname, 'UEFIApp target')

    # add clean target
    make_add_target(path, targetname+'_clean', command+' CleanApp', deps=['FORCE'],\
                    description='Cleaning target \''+targetname+'\'')
    cfg.make.dependencies('clean', targetname+'_clean')

    cfg.make.newline()

def make_add_target(source, name, commands=None, deps=None, phony=False, description=None):
    if name in cfg.targets:
        raise Exception('Duplicate target \''+name+'\' in '+source+'\nPreviously defined in '+cfg.targets[name])

    if not deps:
        deps = []
    if not isinstance(deps, list):
        deps = [deps]

    cfg.make.target(name, commands, deps, phony, description)
    cfg.targets[name] = source

def partitionpath2name(part):
    tmp = part.split('/by-name/')
    if len(tmp) !=2:
        raise Exception('Invalid partition path: %s'  % (part))

    return tmp[1]

def main(argv):
    # get devicename
    if 'DEVICEID' in os.environ:
        cfg.devicename = os.environ['DEVICEID']
        pr_info('Configuring for %s' % cfg.devicename)
    else:
        cfg.devicename = None
        pr_info('Configuring for HOST')

    # get build type
    if 'BUILDTYPE' in os.environ:
        cfg.buildtype = os.environ['BUILDTYPE']
    else:
        cfg.buildtype = 'RELEASE'
    if not (cfg.buildtype=='DEBUG' or cfg.buildtype=='RELEASE'):
        raise Exception('Invalid build type \''+cfg.buildtype+'\'')
    pr_info('Buildtype: '+cfg.buildtype)

    # initialize make
    makeout = StringIO()
    makeoutvars = StringIO()
    cfg.make = make_syntax.Writer(makeout)
    cfg.makevars = make_syntax.Writer(makeoutvars)
    cfg.out = os.path.abspath('out')
    cfg.variables = {}
    cfg.libs = {}
    cfg.helptext = ''
    cfg.targets = {}
    cfg.top = os.path.abspath('')
    cfg.uefird_deps = []

    # create out directory
    try:
        os.makedirs(cfg.out)
    except:
        pass

    # basic variables
    setvar('builddir', cfg.out)
    setvar('OUT', cfg.out)
    setvar('TOP', cfg.top)
    setvar('HOST_OUT', getvar('OUT')+'/host')
    setvar('MAKEFORWARD', getvar('HOST_OUT')+'/makeforward')
    setvar('MAKEFORWARD_PIPES', getvar('HOST_OUT')+'/makeforward_pipes')
    setvar('BUILDTYPE', cfg.buildtype)

    # get target arch
    if 'TARGET_ARCH' in os.environ:
        setvar('TARGET_ARCH', os.environ['TARGET_ARCH'])
    else:
        setvar('TARGET_ARCH', 'arm')

    setvar('TARGET_COMMON_OUT', cfg.out+'/target/common/'+getvar('TARGET_ARCH'))

    # load device config
    if cfg.devicename:
        tmp = cfg.devicename.split('/')
        if len(tmp) != 2:
            raise Exception('Invalid device name')

        # check if device exists
        if cfg.devicename and not os.path.isfile('device/'+cfg.devicename+'/config.ini'):
            subprocess.call([cfg.top+"/build/tools/roomservice.py", cfg.devicename])
            if not os.path.isfile('device/'+cfg.devicename+'/config.ini'):
                raise Exception('Device does not exist')

        cfg.devicenamenice = cfg.devicename.replace('/','-')
        cfg.variableinc = cfg.out+'/variables_'+cfg.devicenamenice+'.mk'

        cfg.configinclude_name = cfg.out+'/config_'+cfg.devicenamenice
        cfg.buildfname = cfg.out+'/build_'+cfg.devicenamenice+'.mk'

        setvar('DEVICE', cfg.devicename)
        setvar('DEVICEVENDOR', tmp[0])
        setvar('DEVICENAME', tmp[1])
        setvar('TARGET_OUT', cfg.out+'/target/'+cfg.devicename)
        setvar('UEFIRD_DIR', getvar('TARGET_OUT')+'/uefird')
        setvar('UEFIRD_CPIO', getvar('UEFIRD_DIR')+'.cpio')

        # parse fstab
        setvar('DEVICE_FSTAB', cfg.top+'/device/'+cfg.devicename+'/fstab.multiboot')
        if not os.path.isfile(getvar('DEVICE_FSTAB')):
            raise Exception('fstab.multiboot does not exist')
        fstab = FSTab(getvar('DEVICE_FSTAB'))

        # get nvvars partition
        nvvarspart = fstab.getNVVarsPartition();
        if not nvvarspart:
            raise Exception('fstab doesn\'t have a nvvars partition')
        setvar('DEVICE_NVVARS_PARTITION', nvvarspart)
        setvar('DEVICE_NVVARS_PARTITION_LK', partitionpath2name(nvvarspart))

        # check if there's an esp partition
        esppart = fstab.getESPPartition()
        if not nvvarspart:
            raise Exception('fstab doesn\'t have a esp partition')

        setvar('DEVICE_DIR', cfg.top+'/device/'+cfg.devicename);
    else:
        cfg.variableinc = cfg.out+'/variables_host.mk'
        cfg.configinclude_name = cfg.out+'/config_host'
        cfg.buildfname = cfg.out+'/build_host.mk'

    # open output files
    cfg.configinclude_sh = open(cfg.configinclude_name+'.sh', "w")
    cfg.configinclude_py = open(cfg.configinclude_name+'.py', "w")
    cfg.configinclude_cmake = open(cfg.configinclude_name+'.cmake', "w")

    # get host type
    kernel_name = os.uname()[0]
    hostname = None
    if kernel_name == 'Linux':
        hosttype = 'linux-x86'
    elif kernel_name == 'Darwin':
        hosttype = 'darwin-x86'
    setvar('HOSTTYPE', hosttype)

    # include file
    cfg.make.include(cfg.variableinc)
    cfg.make.newline()

    # add force target
    cfg.make.comment('# Used to force goals to build.  Only use for conditionally defined goals.')
    cfg.make.target('FORCE')
    cfg.make.newline()

    # add build config
    parse_config('build/config.ini')

    # compiler aliases
    cfg.gcc_linux_var = 'GCC_LINUX_'+getvar('TARGET_ARCH').upper()+'_';
    cfg.gcc_none_var = 'GCC_NONE_'+getvar('TARGET_ARCH').upper()+'_';

    setvar('GCC_LINUX_TARGET_PATH', getvar(cfg.gcc_linux_var+'PATH'));
    setvar('GCC_LINUX_TARGET_NAME', getvar(cfg.gcc_linux_var+'NAME'));
    setvar('GCC_LINUX_TARGET_PREFIX', getvar(cfg.gcc_linux_var+'PREFIX'));

    setvar('GCC_NONE_TARGET_PATH', getvar(cfg.gcc_none_var+'PATH'));
    setvar('GCC_NONE_TARGET_NAME', getvar(cfg.gcc_none_var+'NAME'));
    setvar('GCC_NONE_TARGET_PREFIX', getvar(cfg.gcc_none_var+'PREFIX'));

    # we need the toolchain vars
    evaluatevars()

    # set PATH
    cfg.make._line('export PATH := '+getvar('GCC_LINUX_TARGET_PATH')+':$(PATH)')
    cfg.make._line('export PATH := '+getvar('GCC_NONE_TARGET_PATH')+':$(PATH)')

    # add device config
    if cfg.devicename:
        parse_config('device/'+cfg.devicename+'/config.ini')

    # add build tasks
    for configfile in glob.glob('build/core/tasks/*.ini'):
        parse_config(configfile)

    # add modules
    for moduledir in glob.glob('modules/*'):
        dirname = os.path.basename(os.path.normpath(moduledir))

        # always include moduleconfig if available
        moduleconfigfile = 'build/moduleconfigs/'+dirname+'/EFIDroid.ini'
        if os.path.isfile(moduleconfigfile):
            parse_config(moduleconfigfile, moduledir);

        # detect build system
        moduleefidroidini = moduledir+'/EFIDroid.ini'
        parsed = False
        if os.path.isfile(moduleefidroidini):
            parse_config(moduleefidroidini, moduledir);
            opts = cfg_parse_opts(moduleefidroidini)
            if ('extend' in opts) and (opts['extend']=='1'):
                parsed = False
            else:
                parsed = True

        if parsed == False:
            if os.path.isfile(moduledir+'/CMakeLists.txt'):
                add_cmake_target(moduledir, 'target')
                add_cmake_target(moduledir, 'host')

            elif not os.path.isfile(moduleconfigfile):
                raise Exception('Unknown make system in '+moduledir+'\nYou can manually specify it in '+moduleconfigfile)

        moduledepsfile = moduledir+'/EFIDroidDependencies.ini'
        if os.path.isfile(moduledepsfile):
            parse_deps(moduledepsfile)

    # add apps
    for moduledir in glob.glob('uefi/apps/*'):
        dirname = os.path.basename(os.path.normpath(moduledir))
        moduleefidroidini = moduledir+'/EFIDroid.ini'
        appconfigfile = 'build/uefiappconfigs/'+dirname+'/EFIDroid.ini'

        # detect build system
        parsed = False
        if os.path.isfile(appconfigfile):
            parse_config(appconfigfile, moduledir);
            opts = cfg_parse_opts(moduleefidroidini)
            if ('extend' in opts) and (opts['extend']=='1'):
                parsed = False
            else:
                parsed = True

        if parsed == False:
            if os.path.isfile(moduleefidroidini):
                parse_config(moduleefidroidini, moduledir);
                opts = cfg_parse_opts(moduleefidroidini)
                if ('extend' in opts) and (opts['extend']=='1'):
                    parsed = False
                else:
                    parsed = True

            if parsed == False:
                if os.path.isfile(moduledir+'/CMakeLists.txt'):
                    add_cmake_target(moduledir, 'target')
                    add_cmake_target(moduledir, 'host')

                elif os.path.isfile(moduledir+'/'+dirname+'.inf'):
                    add_uefiapp_target(moduledir)

                elif not os.path.isfile(appconfigfile):
                    raise Exception('Unknown make system in '+moduledir+'\nYou can manually specify it in '+appconfigfile)

        moduledepsfile = moduledir+'/EFIDroidDependencies.ini'
        if os.path.isfile(moduledepsfile):
            parse_deps(moduledepsfile)

    if cfg.devicename:
        # UEFIRD target
        cfg.make.comment('UEFIRD')
        make_add_target(__file__, 'uefird', 'cd $(UEFIRD_DIR) && find . | cpio -o -H newc > $(UEFIRD_CPIO)', phony=True, deps=cfg.uefird_deps)
        cfg.make.newline()

    # clean target
    cfg.make.comment('CLEAN')
    make_add_target(__file__, 'clean', phony=True)
    cfg.make.newline()
    addhelp('clean', 'Clean all projects')

    # distclean target
    cfg.make.comment('DIST')
    make_add_target(__file__, 'distclean', 'rm -Rf \"'+cfg.out+'\"', phony=True)
    cfg.make.newline()
    addhelp('distclean', 'Remove the entire build directory (out)')

    # help target
    addhelp('help', 'Show this help text')
    cfg.make.comment('HELP')
    make_add_target(__file__, 'help', 'echo -e \"'+cfg.helptext.replace('"', '\\"')+'\"', description='Generating Help')
    cfg.make.default(['help'])
    cfg.make.newline()

    # generate make file
    makefile = open(cfg.buildfname, "w")
    makefile.write(makeout.getvalue())
    makefile.close()
    makeout.close()

    # generate includes file
    genvarinc()
    makefile = open(cfg.variableinc, "w")
    makefile.write(makeoutvars.getvalue())
    makefile.close()
    makeoutvars.close()

    # generate cmake toolchains
    gen_toolchains()

    cfg.configinclude_sh.close()
    cfg.configinclude_py.close()
    cfg.configinclude_cmake.close()

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except:
        pr_error('Error: %s' % sys.exc_info()[1])
        raise
