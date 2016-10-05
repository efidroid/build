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

# common imports
import os.path
import sys
import glob
import make_syntax
import os
import subprocess
import os
import hashlib
import urllib
from urlparse import urlparse
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
    if not name:
        raise Exception('Invalid variable name')
    if value == None:
        raise Exception('no value given for variable \''+name+'\'')

    cfg.variables[name] = value

def expandvars_ex(varlist, string):
    # all variables got expanded already so this is much easier
    for k, v in varlist.items():
        string = string.replace('$(%s)' % k, v)

    return string

def expandvars(string):
    return expandvars_ex(cfg.variables, string)

def expandmodulevars(string, module, projecttype):
    module_out = getvar(projecttype.upper()+'_'+module.upper()+'_OUT')
    module_src = getvar(projecttype.upper()+'_'+module.upper()+'_SRC')

    if module_out and module_src:
        string = string.replace('$(%s)' % 'MODULE_OUT', module_out)
        string = string.replace('$(%s)' % 'MODULE_SRC', module_src)
        return string

    return None

def expandmodulevars_novars(string, module_out, module_src):

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

def addhelp(name, text, internal=False):
    cfg.help.append({
        'name': name,
        'text': bldwht.replace('\033', '\\033')+name+': '+txtrst.replace('\033', '\\033')+text.replace('\n', '\\n'+((len(name)+2)*' '))+'\\n',
        'internal':internal
    })

def register_library(target, name, filename, includes, static=True):
    o = Bunch()
    o.name = name
    o.target = target
    o.filename = filename
    o.includes = includes
    o.static = static

    cfg.libs.append(o)

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

    for o in cfg.libs:
        linkage = 'STATIC'
        if not o.static:
            linkage = 'SHARED'

        inlcudesstr = ''
        for include in o.includes:
            inlcudesstr += ' \"'+include+'\"'

        success = False;
        inc_expanded = expandmodulevars(expandvars(inlcudesstr), o.target, 'host')
        file_expanded = expandmodulevars(expandvars(o.filename), o.target, 'host')
        if not inc_expanded==None and not file_expanded==None:
            f = fHost
            f.write('if(NOT "${EFIDROID_TARGET}" STREQUAL "'+o.target+'")\n')
            f.write('add_library("'+o.name+'" '+linkage+' IMPORTED)\n')
            f.write('set_target_properties('+o.name+' PROPERTIES IMPORTED_LOCATION '+ expandvars(file_expanded)+')\n')
            if inc_expanded:
                f.write('include_directories('+inc_expanded+')\n')
            f.write('endif()\n\n')
            f.write('\n')
            success = True

        if cfg.devicename:
            inc_expanded = expandmodulevars(expandvars(inlcudesstr), o.target, 'target')
            file_expanded = expandmodulevars(expandvars(o.filename), o.target, 'target')
            if not inc_expanded==None and not file_expanded==None:
                f = fTarget
                f.write('if(NOT "${EFIDROID_TARGET}" STREQUAL "'+o.target+'")\n')
                f.write('add_library("'+o.name+'" '+linkage+' IMPORTED)\n')
                f.write('set_target_properties('+o.name+' PROPERTIES IMPORTED_LOCATION '+ expandvars(file_expanded)+')\n')
                if inc_expanded:
                    f.write('include_directories('+inc_expanded+')\n')
                f.write('endif()\n\n')
                f.write('\n')
                success = True

        if not success:
            raise Exception('library %s depends on non-existend target %s' % (o.name, o.target))

    if cfg.devicename:
        toolchain_write_footer(fTarget)
        fTarget.close()

    toolchain_write_footer(fHost)
    fHost.close()

def add_ini_target(moduletype, configfile, moduledir, config, section, uefiapp=False):
    targetname = section.split('.', 1)[1]
    targetname_id = targetname.upper()
    targettype = config.get(section, 'type')
    targetrule = targetname+'_rule'
    targetdir  = os.path.abspath(os.path.dirname(configfile))
    targetdeps = []
    targetcompilefn = 'EFIDroidCompile'
    targetforcecompile = True
    targetout = None
    outdir = targetname
    maketargets = []
    configureenv = ''
    makeenv = ''
    configureflags = ''
    generatorflags = ''
    linksource = False
    internalTarget = False
    noprefix = False

    if config.has_option(section, 'dependencies'):
        targetdeps = targetdeps + config.get(section, 'dependencies').split()
    if config.has_option(section, 'compilefunction'):
        targetcompilefn = config.get(section, 'compilefunction')
    if config.has_option(section, 'forcecompile'):
        targetforcecompile = config.get(section, 'forcecompile')=='1'
    if config.has_option(section, 'subtargets'):
        subtargets = config.get(section, 'subtargets').split()
    if config.has_option(section, 'maketargets'):
        maketargets += config.get(section, 'maketargets').split()
    if config.has_option(section, 'configureenv'):
        configureenv += config.get(section, 'configureenv')
    if config.has_option(section, 'makeenv'):
        makeenv += config.get(section, 'makeenv')
    if config.has_option(section, 'configureflags'):
        configureflags += config.get(section, 'configureflags')
    if config.has_option(section, 'generatorflags'):
        generatorflags += config.get(section, 'generatorflags')
    if config.has_option(section, 'linksource'):
        linksource = config.get(section, 'linksource')=='1'
    if config.has_option(section, 'group'):
        internalTarget = config.get(section, 'group')=='internal'

    if uefiapp:
        noprefix = True
    else:
        if config.has_option(section, 'noprefix'):
            noprefix = config.get(section, 'noprefix')=='1'

    # validate target name
    if targetname.startswith(moduletype+'_'):
        pr_fatal('invalid prefix in target name %s' % targetname)

    # add moduletype prefix to target name
    if not noprefix:
        targetname = moduletype+'_'+targetname

    # get moduledir
    if not moduledir:
        moduledir = targetdir
    else:
        moduledir = os.path.abspath(moduledir)

    if targetforcecompile:
        targetdeps += ['FORCE']

    if config.has_option(section, 'outdir'):
        outdir = config.get(section, 'outdir')

    if moduletype=='target':
        targetout = getvar('TARGET_OUT')+'/'+outdir
    elif moduletype=='uefiapp':
        targetout = getvar('TARGET_COMMON_OUT')+'/'+outdir
    elif moduletype=='host':
        targetout = getvar('HOST_OUT')+'/'+outdir
    else:
        raise Exception('Invalid moduletype \''+moduletype+'\'')

    # expand some of the options
    configureflags = expandmodulevars_novars(configureflags, targetout, moduledir)
    generatorflags = expandmodulevars_novars(generatorflags, targetout, moduledir)

    # add rule
    command = ''
    if targettype == 'script':
        targetscriptfile = config.get(section, 'scriptfile')
        targetscriptfile_abs = targetdir+'/'+targetscriptfile
        if not os.path.isfile(targetscriptfile_abs):
            raise Exception('%s: \'%s\' doesn\'t exist' % (configfile, targetscriptfile_abs))

        command = 'build/tools/runscript "'+\
                   cfg.out+'" "'+cfg.configinclude_name+'" "'+targetscriptfile_abs+'"'+\
                   ' "'+moduletype+'" "'+targetname+'" "'+targetout+'" "'+moduledir+'"'

        # add build target
        make_add_target(configfile, targetname, command+' '+targetcompilefn, deps=targetdeps,\
                        description='Compiling target \''+targetname+'\'', moduletype=moduletype)

        # add clean target
        make_add_target(configfile, targetname+'_clean', command+' Clean', deps=['FORCE'],\
                        description='Cleaning target \''+targetname+'\'', moduletype=moduletype)
        cfg.make.dependencies('clean', targetname+'_clean')

        # add distclean target
        make_add_target(configfile, targetname+'_distclean', command+' DistClean',\
                        description='Dist-Cleaning target \''+targetname+'\'', moduletype=moduletype)
        cfg.make.dependencies('distclean', targetname+'_distclean')

        # add help entry
        if config.has_option(section, 'help'):
            addhelp(targetname, config.get(section, 'help'), internal=internalTarget)
        else:
            addhelp(targetname, '\''+moduletype+'/'+targettype+'\' target', internal=internalTarget)

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
            raise Exception('no generator found for '+moduledir)

        # add CC and CXX environment variables
        generic_env = ''
        if moduletype == 'target':
            generic_env += ' CC="'+getvar('GCC_LINUX_TARGET_PREFIX')+'gcc" CXX="'+getvar('GCC_LINUX_TARGET_PREFIX')+'g++"'
            generic_env += ' PKG_CONFIG_DIR= PKG_CONFIG_LIBDIR= PKG_CONFIG_SYSROOT_DIR='
        configureenv += generic_env
        makeenv += generic_env

        compiledir = moduledir
        if linksource:
            compiledir = targetout

            # add lns target
            make_add_target(configfile, targetout+'/'+generator, cfg.top+'/build/tools/lns -rf \"'+moduledir+'\" \"'+targetout+'\"',\
                            description='running lns on target \''+targetname+'\'', moduletype=moduletype)

        # add autogen target
        if not generator=='configure':
            make_add_target(configfile, compiledir+'/configure', 'cd \"'+compiledir+'\" && ./'+generator+" "+generatorflags, deps=compiledir+'/'+generator,\
                            description='Autoconfiguring target \''+targetname+'\'', moduletype=moduletype)

        # add configure target
        if moduletype=='target' and getvar('GCC_LINUX_TARGET_NAME')!='native':
            configureflags += ' --host '+getvar('GCC_LINUX_TARGET_NAME')
        commands = [
            'mkdir -p \"'+targetout+'\"',
            'cd \"'+targetout+'\" && '+configureenv+' \"'+compiledir+'/configure\" '+configureflags
        ]
        make_add_target(configfile, targetout+'/Makefile', commands, deps=compiledir+'/configure',\
                        description='Configuring target \''+targetname+'\'', moduletype=moduletype)

        # add make target
        make_add_target(configfile, targetname, 'cd \"'+targetout+'\" && '+makeenv+' $(MAKE) '+(' '.join(maketargets)), \
                        deps=targetdeps+[targetout+'/Makefile'], description='Compiling target \''+targetname+'\'', moduletype=moduletype)

        # add clean target
        make_add_target(configfile, targetname+'_clean', '[ -f \"'+targetout+'\" ] && cd \"'+targetout+'\" && [ -f Makefile ] && $(MAKE) clean || true',\
                        deps=['FORCE'], description='Cleaning target \''+targetname+'\'', moduletype=moduletype)
        cfg.make.dependencies('clean', targetname+'_clean')

        # add distclean target
        make_add_target(configfile, targetname+'_distclean', '[ -f \"'+targetout+'\" ] && cd \"'+targetout+'\" && [ -f Makefile ] && $(MAKE) distclean || true', \
                        deps=[targetname+'_clean'], description='Dist-Cleaning target \''+targetname+'\'', moduletype=moduletype)
        cfg.make.dependencies('distclean', targetname+'_distclean')

        # add help entry
        if config.has_option(section, 'help'):
            addhelp(targetname, config.get(section, 'help'), internal=internalTarget)
        else:
            addhelp(targetname, '\''+moduletype+'/'+targettype+'\' target', internal=internalTarget)

    elif targettype == 'cmake':
        add_cmake_target(os.path.dirname(configfile), moduletype, moduledir, moduledeps=targetdeps, maketargets=maketargets)

    elif targettype == 'command':
        command = expandvars(config.get(section, 'command'))
         # add make target
        make_add_target(configfile, targetname, command, deps=targetdeps, description='Compiling target \''+targetname+'\'', moduletype=moduletype)

    else:
        raise Exception('Invalid target type \''+targettype+'\' in '+configfile)

    # set target variables            
    setvar(targetname_id+'_CONFIG_DIR', targetdir)
    setvar(targetname.upper()+'_OUT', targetout)
    setvar(targetname.upper()+'_SRC', moduledir)

def process_target_section(configfile, moduledir, config, section, uefiapp=False):
    moduletypes = []

    if uefiapp:
        moduletypes.append('target')
    else:
        moduletypes.append('target')
        moduletypes.append('host')

        if config.has_option(section, 'moduletypes'):
            moduletypes = config.get(section, 'moduletypes').split()

    for moduletype in moduletypes:
        # validate moduletype
        if not moduletype=='target' and not moduletype=='host' and not moduletype=='uefiapp':
            raise Exception('Invalid module type \''+moduletype+'\' in '+configfile)

        # skip device targets if we're building in host-only mode
        if not cfg.devicename and moduletype=='target':
            if len(moduletypes)==1:
                config.ignore_unused_options = True
            continue

        add_ini_target(moduletype, configfile, moduledir, config, section, uefiapp=uefiapp)

class CheckingRawConfigParser(ConfigParser.RawConfigParser):
    def __init__(self, *args, **kwargs):
        ConfigParser.RawConfigParser.__init__(self, *args, **kwargs)

        self.used_options = {}
        self.ignore_unused_options = False;

    def get(self, *args, **kwargs):
        section = args[0]
        option = args[1]

        if not section in self.used_options:
            self.used_options[section] = [];

        self.used_options[section] += [option]

        return ConfigParser.RawConfigParser.get(self, *args, **kwargs)

    def get_unused_options(self, section):
        arr = []

        if not section in self.used_options:
            self.used_options[section] = [];

        for item in self.items(section):
            if not item[0] in self.used_options[section]:
                arr += [item[0]]

        return arr

    def check_unused_options(self, section, configfile):
        if self.ignore_unused_options:
            return
        if section == 'variables':
            return
        if section == 'parseopts':
            return
        if section.startswith('toolchain.'):
            return

        unused_options = self.get_unused_options(section)
        for option in unused_options:
            pr_error('unused option \''+option+'\' in section \''+section+'\' of '+configfile)

        if len(unused_options)>0:
            raise Exception('')

def parse_config(configfile, moduledir=None, moduledeps=[], uefiapp=False):
    cfg.make.comment(configfile)

    config = CheckingRawConfigParser(allow_no_value=True)
    config.optionxform = str
    config.read(configfile)

    for section in config.sections():
        if section == 'variables':
            for (name, value) in config.items(section):
                setvar(name, value)

        elif section.startswith('toolchain.'):
            parts = section.split('.')
            identifier = '_'.join(parts[1:])
            if identifier in cfg.toolchains:
                raise Exception('Toolchain \''+identifier+'\' does already exist')

            cfg.toolchains[identifier] = {}
            for (name, value) in config.items(section):
                cfg.toolchains[identifier][name] = value

        elif section.startswith('target.'):
            process_target_section(configfile, moduledir, config, section, uefiapp=uefiapp)

        elif section.startswith('library.'):
            libname = section.split('.', 1)[1]
            filename = config.get(section, 'file')
            target = config.get(section, 'target')

            includes = []
            if config.has_option(section, 'includes'):
                includes += config.get(section, 'includes').split()
            if config.has_option(section, 'name'):
                libname = config.get(section, 'name')

            register_library(target, libname, filename, includes)

        elif section.startswith('uefird.'):
            idx = section.split('.', 1)[1]
            source = config.get(section, 'source')
            destination = config.get(section, 'destination')

            if not cfg.devicename:
                continue

            if moduledir:
                source = source.replace('$(%s)' % 'MODULE_SRC', cfg.top+'/'+moduledir)

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

        config.check_unused_options(section, configfile)

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

def add_cmake_target(path, projecttype, modulesrc=None, maketargets=None, disableprefix=False, moduledeps=[]):
    cfg.make.comment(path)

    dirname = os.path.basename(os.path.normpath(path))
    if disableprefix:
        targetname = dirname
    else:
        targetname = projecttype+'_'+dirname
    targetdeps = ['FORCE'] + moduledeps
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
        cmakeargs += ' -DCMAKE_EXE_LINKER_FLAGS=\"-static\"'
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('TARGET_OUT')+'/toolchain.cmake'
    elif projecttype == 'host':
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('HOST_OUT')+'/toolchain.cmake'
    else:
        raise Exception('Invalid projecttype \''+projecttype+'\'')

    cmakeargs += ' -DEFIDROID_TARGET='+dirname

    if modulesrc:
        cmakeargs += ' -DMODULE_SRC='+os.path.abspath(modulesrc)

    if projecttype=='target':
        outdir = getvar('TARGET_OUT')+'/'+dirname
    elif projecttype=='host':
        outdir = getvar('HOST_OUT')+'/'+dirname
    else:
        raise Exception('Invalid projecttype \''+projecttype+'\'')

    # add rule
    make_add_target(path, targetname, [
        'mkdir -p \"'+outdir+'\"',
        'cd \"'+outdir+'\" && cmake '+cmakeargs+' '+os.path.abspath(path)+' && $(MAKE)'
    ], description='Compiling target \''+targetname+'\'', deps=targetdeps, moduletype=projecttype)
    addhelp(targetname, 'CMake target')

    # add clean rule
    make_add_target(path, targetname+'_clean', [
        'if [ -d \"'+outdir+'\" ];then ' +
        'cd \"'+outdir+'\" && $(MAKE) clean;' +
        'fi'
    ], description='Cleaning target \''+targetname+'\'', deps=['FORCE'], moduletype=projecttype)
    cfg.make.dependencies('clean', targetname+'_clean')

    # add distclean rule
    make_add_target(path, targetname+'_distclean', [
        'rm -Rf \"'+outdir+'\"'
    ], description='Dist-Cleaning target \''+targetname+'\'', moduletype=projecttype)
    cfg.make.dependencies('distclean', targetname+'_distclean')

    cfg.make.newline()

    setvar(targetname.upper()+'_OUT', outdir)
    setvar(targetname.upper()+'_SRC', os.path.abspath(path))

def add_uefiapp_target(path, moduledeps=[]):
    cfg.make.comment(path)

    dirname = os.path.basename(os.path.normpath(path))
    targetname = 'uefiapp_'+dirname
    targetdeps = ['FORCE'] + moduledeps

    scriptfile  = os.path.abspath('build/core/tasks/edk2-appbase.sh')
    targetout  = os.path.abspath(getvar('TARGET_COMMON_OUT')+'/'+targetname)
    moduledir = os.path.abspath('build/core/tasks')
    targetcompilefn = 'CompileApp'
    command = 'UEFIAPP="'+cfg.top+'/'+path+'" build/tools/runscript "'+\
               cfg.out+'" "'+cfg.configinclude_name+'" "'+scriptfile+'"'+\
               ' "host" "edk2_appbase" "'+targetout+'" "'+moduledir+'"'

    # add build target
    make_add_target(path, targetname, command+' '+targetcompilefn, deps=targetdeps,\
                    description='Compiling target \''+targetname+'\'', moduletype='target')
    addhelp(targetname, 'UEFIApp target')

    # add clean target
    make_add_target(path, targetname+'_clean', command+' Clean', deps=['FORCE'],\
                    description='Cleaning target \''+targetname+'\'', moduletype='target')
    cfg.make.dependencies('clean', targetname+'_clean')

    # add distclean target
    make_add_target(path, targetname+'_distclean', command+' DistClean',\
                    description='Dist-Cleaning target \''+targetname+'\'', moduletype='target')
    cfg.make.dependencies('distclean', targetname+'_distclean')

    cfg.make.newline()

def make_add_target(source, name, commands=None, deps=None, phony=False, description=None, moduletype=None):
    if name in cfg.targets:
        raise Exception('Duplicate target \''+name+'\' in '+source+'\nPreviously defined in '+cfg.targets[name]['source'])

    if not deps:
        deps = []
    if not isinstance(deps, list):
        deps = [deps]

    cfg.make.target(name, commands, [], phony, description)
    cfg.targets[name] = {
        'source':source,
        'deps':deps,
        'moduletype':moduletype,
    }

def make_add_dependencies():
    for name in cfg.targets:
        info = cfg.targets[name]
        deps = []

        for dep in info['deps']:
            # ignore explicit deps
            if dep.startswith('target_') or dep.startswith('host_') or dep=='FORCE' or info['moduletype']==None:
                deps.append(dep)
                continue

            # if the target exists, use it
            if dep in cfg.targets:
                deps.append(dep)
                continue

            # this should be an error, but since make_syntax checks this anyway, we add it as is
            newdepname = info['moduletype'] + '_' + dep
            if not newdepname in cfg.targets:
                deps.append(dep)
                continue

            # add the new depname
            depinfo = cfg.targets[newdepname]
            deps.append(newdepname)

        if len(deps)==0:
            continue

        cfg.make.dependencies(name, deps)

def partitionpath2name(part):
    tmp = part.split('/by-name/')
    if len(tmp) !=2:
        raise Exception('Invalid partition path: %s'  % (part))

    return tmp[1]

def sha1(filepath):
    sha1lib = hashlib.sha1()

    with open(filepath, 'rb') as f:
        sha1lib.update(f.read())

    return sha1lib.hexdigest()

def setup_toolchain(toolchain):
    # expand all variables
    for k,v in toolchain.items():
        toolchain[k] = expandvars(v)

    # this toolchain doesn't provide a directory(it's native)
    if not 'path' in toolchain:
        return

    # stop if toolchain dir does already exist
    if os.path.isdir(toolchain['path']):
        return

    # check if we have a source
    if not 'src' in toolchain:
        raise Exception('Toolchain in \''+toolchain['path']+'\' doesn\'t exist and has no source option')

    # make cachedir
    cachedir = 'prebuilts/cache'
    try:
        os.makedirs(cachedir)
    except:
        pass

    # download toolchain
    filename = urllib.unquote(os.path.basename(urlparse(toolchain['src']).path))
    downloadfile = cachedir+'/'+filename
    if not os.path.isfile(downloadfile) or not sha1(downloadfile)==toolchain['sha1']:
        pr_alert('Downloading toolhain \'%s\' ...' % filename)
        p = subprocess.Popen(['curl', '-L', '-o', downloadfile, toolchain['src']])
        p.communicate()
        if p.returncode:
            pr_fatal('Can\'t download toolchain')

        # verify checksum
        if not sha1(downloadfile)==toolchain['sha1']:
            pr_fatal('sha1sum doesn\'t match')

    # make toolchain dir
    try:
        os.makedirs(getvar('GCC_TARGET_DIR'))
    except:
        pass

    # extract toolchain
    pr_alert('extracting '+downloadfile+' ...')
    p = subprocess.Popen(['tar', 'xf', downloadfile, '-C', getvar('GCC_TARGET_DIR')])
    p.communicate()
    if p.returncode:
        pr_fatal('Can\'t extract toolchain')

    if not os.path.isdir(toolchain['path']):
        pr_fatal('invalid toolchain')


def setup_toolchain_variables(prefix, toolchain):
    # expand all local variables
    for k,v in toolchain.items():
        v = expandvars_ex(toolchain, v)
        toolchain[k] = v

    if toolchain['name'] == 'native':
        setvar(prefix+'_NAME', 'native')
        setvar(prefix+'_PREFIX', '')
    else:
        if 'path' in toolchain:
            setvar(prefix+'_PATH', toolchain['path'])
        setvar(prefix+'_NAME', toolchain['name'])
        setvar(prefix+'_PREFIX', toolchain['prefix'])

def process_module(moduledir, uefiapp=False):
    dirname = os.path.basename(os.path.normpath(moduledir))
    if uefiapp:
        moduleconfigfile = 'build/uefiappconfigs/'+dirname+'/EFIDroid.ini'
    else:
        moduleconfigfile = 'build/moduleconfigs/'+dirname+'/EFIDroid.ini'
    moduleefidroidini = moduledir+'/EFIDroid.ini'
    moduledepsfile = moduledir+'/EFIDroidDependencies.ini'
    moduledeps = []

    # always include moduleconfig if available
    if os.path.isfile(moduleconfigfile):
        if os.path.isfile(moduleefidroidini):
            raise Exception('both %s and %s were found' % (moduleconfigfile, moduleefidroidini))

        parse_config(moduleconfigfile, moduledir, uefiapp=uefiapp);

    # detect build system
    parsed = False
    if os.path.isfile(moduleefidroidini):
        # parse opts
        opts = cfg_parse_opts(moduleefidroidini)

        # add moduledeps
        if ('moduledeps' in opts):
            moduledeps += opts['moduledeps'].split()

        # parse config normally
        parse_config(moduleefidroidini, moduledir, moduledeps=moduledeps, uefiapp=uefiapp);

        # check if this is a extension only
        if ('extend' in opts) and (opts['extend']=='1'):
            parsed = False
        else:
            parsed = True

    if parsed == False:
        if os.path.isfile(moduledir+'/CMakeLists.txt'):
            add_cmake_target(moduledir, 'target', moduledeps=moduledeps)
            add_cmake_target(moduledir, 'host', moduledeps=moduledeps)

        elif uefiapp and os.path.isfile(moduledir+'/'+dirname+'.inf'):
            add_uefiapp_target(moduledir, moduledeps=moduledeps)

        elif not os.path.isfile(moduleconfigfile):
            if moduledir.startswith("modules/selinux_"):
                return

            pr_warning('Unknown make system in '+moduledir+'\nYou can manually specify it in '+moduleconfigfile)
            return

    if os.path.isfile(moduledepsfile):
        pr_warning('Deprecated file \''+moduledepsfile+'\'')

def main(argv):
    # get devicename
    if 'DEVICEID' in os.environ:
        cfg.devicename = os.environ['DEVICEID']
        pr_alert('Configuring for %s' % cfg.devicename)
    else:
        cfg.devicename = None
        pr_alert('Configuring for HOST')

    # get build type
    if 'BUILDTYPE' in os.environ:
        cfg.buildtype = os.environ['BUILDTYPE']
    else:
        cfg.buildtype = 'USERDEBUG'
    if not (cfg.buildtype=='DEBUG' or cfg.buildtype=='USERDEBUG' or cfg.buildtype=='RELEASE'):
        raise Exception('Invalid build type \''+cfg.buildtype+'\'')
    pr_alert('Buildtype: '+cfg.buildtype)

    # initialize make
    makeout = StringIO()
    makeoutvars = StringIO()
    cfg.make = make_syntax.Writer(makeout)
    cfg.makevars = make_syntax.Writer(makeoutvars)
    cfg.out = os.path.abspath('out')
    cfg.variables = {}
    cfg.libs = []
    cfg.help = []
    cfg.targets = {}
    cfg.top = os.path.abspath('')
    cfg.uefird_deps = []
    cfg.toolchains = {}

    # create out directory
    try:
        os.makedirs(cfg.out)
    except:
        pass

    # basic variables
    setvar('OUT', cfg.out)
    setvar('TOP', cfg.top)
    setvar('HOST_OUT', getvar('OUT')+'/host')
    setvar('MAKEFORWARD', getvar('HOST_OUT')+'/makeforward')
    setvar('BUILDTYPE', cfg.buildtype)

    # get target arch
    if 'EFIDROID_TARGET_ARCH' in os.environ:
        setvar('EFIDROID_TARGET_ARCH', os.environ['EFIDROID_TARGET_ARCH'])
    else:
        setvar('EFIDROID_TARGET_ARCH', 'arm')
    pr_alert('Architecture: %s' % getvar('EFIDROID_TARGET_ARCH'))

    setvar('TARGET_COMMON_OUT', cfg.out+'/target/common/'+getvar('EFIDROID_TARGET_ARCH'))

    # load device config
    if cfg.devicename:
        tmp = cfg.devicename.split('/')
        if len(tmp) != 2:
            raise Exception('Invalid device name: '+cfg.devicename)

        # check if device exists
        roomservicerc = 0
        if cfg.devicename:
            # run roomservice
            if not os.path.isfile('device/'+cfg.devicename+'/config.ini'):
                roomservicerc = subprocess.call([cfg.top+'/build/tools/roomservice.py', cfg.devicename])
            else:
                roomservicerc = subprocess.call([cfg.top+'/build/tools/roomservice.py', cfg.devicename, 'true'])

            # check return code
            if roomservicerc != 0:
                raise Exception('roomservice error: %d' % (roomservicerc))

            # check if we finally have a device dir now
            if not os.path.isfile('device/'+cfg.devicename+'/config.ini'):
                raise Exception('Device \''+cfg.devicename+'\' does not exist')

        setvar('DEVICE', cfg.devicename)
        setvar('DEVICEVENDOR', tmp[0])
        setvar('DEVICENAME', tmp[1])
        setvar('TARGET_OUT', cfg.out+'/target/'+cfg.devicename)
        setvar('UEFIRD_DIR', getvar('TARGET_OUT')+'/uefird')
        setvar('UEFIRD_CPIO', getvar('UEFIRD_DIR')+'.cpio')

        cfg.devicenamenice = cfg.devicename.replace('/','-')
        cfg.configinclude_name = getvar('TARGET_OUT')+'/config'
        cfg.buildfname = getvar('TARGET_OUT')+'/build.mk'

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
        if not esppart:
            raise Exception('fstab doesn\'t have a esp partition')

        setvar('DEVICE_DIR', cfg.top+'/device/'+cfg.devicename);

        uefiparts = fstab.getUEFIPartitionNameList()
        if len(uefiparts) < 1:
            raise Exception('fstab doesn\'t have any uefi partitions')
        setvar('DEVICE_UEFI_PARTITIONS', ' '.join(uefiparts))

        # create target dir
        if not os.path.isdir(getvar('TARGET_OUT')):
            os.makedirs(getvar('TARGET_OUT'))
    else:
        cfg.configinclude_name = getvar('HOST_OUT')+'/config'
        cfg.buildfname = getvar('HOST_OUT')+'/build.mk'

    # create host dir
    if not os.path.isdir(getvar('HOST_OUT')):
        os.makedirs(getvar('HOST_OUT'))

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
    cfg.configinclude_mk = cfg.configinclude_name+'.mk'
    cfg.make.include(cfg.configinclude_mk)
    cfg.make.newline()

    # add force target
    cfg.make.comment('Used to force goals to build.  Only use for conditionally defined goals.')
    cfg.make.target('FORCE')
    cfg.make.newline()

    # add build config
    parse_config('build/config.ini')

    # get selected toolchain name
    toolchain_name_gcc_linux = 'gcc6'
    if 'EFIDROID_TOOLCHAIN_NAME_GCC_LINUX' in os.environ:
       toolchain_name_gcc_linux = os.environ['EFIDROID_TOOLCHAIN_NAME_GCC_LINUX']
    pr_alert('Toolchain-LINUX: '+toolchain_name_gcc_linux)

    toolchain_name_gcc_none = 'gcc6'
    if 'EFIDROID_TOOLCHAIN_NAME_GCC_NONE' in os.environ:
       toolchain_name_gcc_none = os.environ['EFIDROID_TOOLCHAIN_NAME_GCC_NONE']
    pr_alert('Toolchain-NONE: '+toolchain_name_gcc_none)

    if toolchain_name_gcc_linux == 'native':
        cfg.toolchain_gcc_linux = cfg.toolchains['native']
    else:
        toolchain_id_linux = 'gcc_linux_'+getvar('EFIDROID_TARGET_ARCH')+'_'+toolchain_name_gcc_linux
        if not toolchain_id_linux in cfg.toolchains:
            raise Exception(getvar('EFIDROID_TARGET_ARCH')+' Toolchain \''+toolchain_name_gcc_linux+'\' doesn\'t support gcc_linux')

        cfg.toolchain_gcc_linux = cfg.toolchains[toolchain_id_linux]

    if toolchain_name_gcc_none == 'native':
        cfg.toolchain_gcc_none = cfg.toolchains['native']
    else:
        toolchain_id_none  = 'gcc_none_' +getvar('EFIDROID_TARGET_ARCH')+'_'+toolchain_name_gcc_none
        if not toolchain_id_none  in cfg.toolchains:
            raise Exception(getvar('EFIDROID_TARGET_ARCH')+' Toolchain \''+toolchain_name_gcc_none+'\' doesn\'t support gcc_none')

        cfg.toolchain_gcc_none  = cfg.toolchains[toolchain_id_none]

    # setup variables needed by our modules
    setup_toolchain_variables('GCC_LINUX_TARGET', cfg.toolchain_gcc_linux)
    setup_toolchain_variables('GCC_NONE_TARGET',  cfg.toolchain_gcc_none)

    # we need the toolchain vars
    evaluatevars()

    # set PATH
    if getvar('GCC_LINUX_TARGET_PATH'):
        cfg.make._line('export PATH := '+getvar('GCC_LINUX_TARGET_PATH')+':$(PATH)')
    if getvar('GCC_NONE_TARGET_PATH'):
        cfg.make._line('export PATH := '+getvar('GCC_NONE_TARGET_PATH')+':$(PATH)')

    # add device config
    if cfg.devicename:
        parse_config('device/'+cfg.devicename+'/config.ini')

    # add build tasks
    for configfile in glob.glob('build/core/tasks/*.ini'):
        parse_config(configfile)

    # add modules
    for moduledir in glob.glob('modules/*'):
        process_module(moduledir)

    # add apps
    for moduledir in glob.glob('uefi/apps/*'):
        process_module(moduledir, uefiapp=True)

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

    # add help for 'help
    addhelp('help', 'Show available targets')
    addhelp('help-internal', 'Show available targets including internal ones')

    # sort help
    cfg.help = sorted(cfg.help, key=lambda k: k['name'])

    # build helptext
    helptext = ''
    helptext_all = ''
    for o in cfg.help:
        helptext_all += o['text']
        if not o['internal']:
            helptext += o['text']

    # help target
    cfg.make.comment('HELP')
    make_add_target(__file__, 'help', 'echo -e \"'+helptext.replace('"', '\\"')+'\"', description='Generating Help', phony=True)
    cfg.make.default(['help'])
    cfg.make.newline()

    # help target
    cfg.make.comment('HELP-INTERNAL')
    make_add_target(__file__, 'help-internal', 'echo -e \"'+helptext_all.replace('"', '\\"')+'\"', description='Generating Help', phony=True)
    cfg.make.newline()

    make_add_dependencies()
    cfg.make.check_dependencies()

    # generate make file
    makefile = open(cfg.buildfname, "w")
    makefile.write(makeout.getvalue())
    makefile.close()
    makeout.close()

    # generate includes file
    genvarinc()
    makefile = open(cfg.configinclude_mk, "w")
    makefile.write(makeoutvars.getvalue())
    makefile.close()
    makeoutvars.close()

    # generate cmake toolchains
    gen_toolchains()

    cfg.configinclude_sh.close()
    cfg.configinclude_py.close()
    cfg.configinclude_cmake.close()

    setup_toolchain(cfg.toolchain_gcc_linux)
    setup_toolchain(cfg.toolchain_gcc_none)

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except:
        pr_error('Error: %s' % sys.exc_info()[1])
        raise
