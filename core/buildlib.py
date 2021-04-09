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

import os
import make_syntax
import subprocess
import copy
import re
import hashlib
from utils import *
from fstab import *

# compatibility imports
try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

try:
    import ConfigParser
except ImportError:
    import configparser as ConfigParser

class VariableSpace:
    __verify_pattern = re.compile('\$\((\w+)\)')

    def __init__(self):
        self.vars = {}

    def has(self, name):
        if not name:
            raise Exception('Invalid variable name')

        return name in self.vars

    def get(self, name, throw=True):
        if not name in self.vars:
            if throw:
                raise Exception('variable \''+name+'\' not found')
            else:
                return None

        return self.vars[name]

    def set(self, name, value):
        if not name:
            raise Exception('Invalid variable name')
        if value == None:
            raise Exception('no value given for variable \''+name+'\'')

        self.vars[name] = value

    def evaluate_str(self, s):
        parsedvalue = s
        processed = 1
        count = 0
        while processed > 0:
            processed = 0
            nvalue = parsedvalue

            vars_to_replace = re.findall(VariableSpace.__verify_pattern, nvalue)
            for varname in vars_to_replace:
                if varname in self.vars:
                    nvalue = nvalue.replace('$('+varname+')', self.vars[varname])

            if nvalue != parsedvalue:
                parsedvalue = nvalue
                processed += 1

            count += 1
            if count==10:
                raise Exception('Variable recursion in: '+s)

        return parsedvalue

    @staticmethod
    def evaluate_str_all(s, spaces):
        parsedvalue = s
        processed = 1
        count = 0
        while processed > 0:
            processed = 0

            vars_to_replace = re.findall(VariableSpace.__verify_pattern, parsedvalue)
            for space in spaces:
                nvalue = parsedvalue

                for varname in vars_to_replace:
                    if varname in space.vars:
                        nvalue = nvalue.replace('$('+varname+')', space.vars[varname])

                if nvalue != parsedvalue:
                    parsedvalue = nvalue
                    processed += 1

            count += 1
            if count==10:
                raise Exception('Variable recursion in: '+s)

        return parsedvalue

    @staticmethod
    def verify(s):
        matches = re.findall(VariableSpace.__verify_pattern, s)
        if len(matches)>0 and not 'MAKE' in matches:
            raise Exception('unexpanded variables in: '+s)

    def __deepcopy__(self, memo):
        n = VariableSpace()
        n.vars = copy.copy(self.vars)
        n.dirty = True
        return n

    def __str__(self):
        return self.vars.__str__()

    def __repr__(self):
        return self.vars.__repr__()

class Context:
    __valid_buildtypes = ['DEBUG', 'USERDEBUG', 'RELEASE']

    def __init__(self):
        self.extdata = Bunch()
        self.toolchains = []
        self.toolchains_used = []
        self.targets = []
        self.iniparser = INIParser(self)
        self.moduleparser = ModuleParser(self)
        self.clazzes = []
        self.architectures = []
        self.globalvars = VariableSpace()
        self.clazzvars = {}
        self.cleantargets = []
        self.distcleantargets = []
        self.defaultarchitectures = []
        self.uefivars = VariableSpace()

        self.globalvars.set('TOP', os.path.abspath(''))

        self.enableClazz('host')

        # get build type
        buildtype = 'USERDEBUG'
        if 'EFIDROID_BUILDTYPE' in os.environ:
            buildtype = os.environ['EFIDROID_BUILDTYPE']
        if not buildtype in Context.__valid_buildtypes:
            raise Exception('Invalid build type \''+buildtype+'\'')
        self.globalvars.set('BUILDTYPE', buildtype)

        # get host type
        kernel_name = os.uname()[0]
        if kernel_name == 'Linux':
            hosttype = 'linux-x86'
        elif kernel_name == 'Darwin':
            hosttype = 'darwin-x86'
        else:
            raise Exception('Unsupported kernel \''+kernel_name+'\'')
        self.globalvars.set('HOSTTYPE', hosttype)

        # use architectures from environment variable
        if 'EFIDROID_TARGET_ARCH' in os.environ:
            self.defaultarchitectures = os.environ['EFIDROID_TARGET_ARCH'].split()

        # get device id
        if 'EFIDROID_DEVICEID' in os.environ:
            deviceid = os.environ['EFIDROID_DEVICEID']
            self.defaultarchitectures = ['arm']

            # add device class
            self.enableClazz('target')
            self.enableClazz('device')

            # parse device id
            tmp = deviceid.split('/')
            if len(tmp) != 2:
                raise Exception('Invalid device id: '+deviceid)

            # run roomservice
            roomservicerc = 0
            path_roomservice = 'build/tools/roomservice.py'
            if not os.path.isfile('device/'+deviceid+'/config.ini'):
                roomservicerc = subprocess.call([path_roomservice, deviceid])
            else:
                roomservicerc = subprocess.call([path_roomservice, deviceid, 'true'])

            # check return code
            if roomservicerc != 0:
                raise Exception('roomservice error: %d' % (roomservicerc))

            # check if we finally have a device dir now
            path_deviceconfig = 'device/'+deviceid+'/config.ini'
            if not os.path.isfile(path_deviceconfig):
                raise Exception('Device \''+deviceid+'\' does not exist')

            # set device variables
            self.clazzvars['device'].set('DEVICE', deviceid)
            self.clazzvars['device'].set('DEVICEVENDOR', tmp[0])
            self.clazzvars['device'].set('DEVICENAME', tmp[1])
            self.clazzvars['device'].set('DEVICE_OUT', '$(OUT)/device/$(DEVICE)')
            self.clazzvars['device'].set('DEVICE_DIR', '$(TOP)/device/$(DEVICE)');

    def __addClazzVariableSpace(self, name, arch=None):
        if arch:
            clazzname = name+'_'+arch
            outdir = '$(OUT)/'+name+'/'+arch
        else:
            clazzname = name
            outdir = '$(OUT)/'+name

        self.clazzvars[clazzname] = VariableSpace()
        if name!='device':
            self.clazzvars[clazzname].set(clazzname.upper()+'_OUT', outdir)

    def enableClazz(self, name):
        if name in self.clazzes:
            return

        self.clazzes.append(name)
        if name=='target':
            for arch in self.architectures:
                self.__addClazzVariableSpace(name, arch)
        else:
            self.__addClazzVariableSpace(name)

    def getClassVariableSpace(self, target):
        if target.clazz=='target':
            arch = target.vars.get('MODULE_ARCH', throw=False)
            if arch:
                return self.clazzvars['target_'+arch]
        else:
            return self.clazzvars[target.clazz]

        return None

    def expandVariables(self, target, s, otherspaces=[]):
        spaces = []

        if target:
            # target variables first
            spaces.append(target.vars)

            # class variables
            clazzspace = self.getClassVariableSpace(target)
            if clazzspace:
                spaces.append(clazzspace)

            # device targets can use 'target' variables too
            if target.clazz=='device':
                arch = target.vars.get('MODULE_ARCH', throw=False)
                if arch:
                    spaces.append(self.clazzvars['target_'+arch])

            # every target can use host variables (Host already has them)
            if target.clazz!='host':
                spaces.append(self.clazzvars['host'])

        # everyone can use global variables
        spaces.append(self.globalvars)

        for o in otherspaces:
            spaces.append(o)

        return VariableSpace.evaluate_str_all(s, spaces)

    def enableArch(self, arch):
        if arch in self.architectures:
            return

        self.architectures.append(arch)
        if 'target' in self.clazzes:
            self.__addClazzVariableSpace('target', arch)

    def getTarget(self, name):
        for target in self.targets:
            if target.name==name:
                return target
        return None

    def removeTarget(self, o):
        if isinstance(o, str):
            if o in self.cleantargets:
                self.cleantargets.remove(o)
            if o in self.distcleantargets:
                self.distcleantargets.remove(o)

            for i in range(len(self.targets)):
                target = self.targets[i]
                if target.name==o:
                    del self.targets[i]
                    return
        else:
            if o.name in self.cleantargets:
                self.cleantargets.remove(o.name)
            if o.name in self.distcleantargets:
                self.distcleantargets.remove(o.name)

            for i in range(len(self.targets)):
                target = self.targets[i]
                if target is o:
                    del self.targets[i]
                    return

        raise Exception('target %s is not in the list' % o)

    def addTarget(self, target):
        if not target.name:
            raise Exception('target \''+target.name+'\' doesn\'t have a name')

        if not target.clazz in self.clazzes:
            raise Exception('target \''+target.name+'\' uses disabled clazz \''+target.clazz+'\'')

        self.targets.append(target)


    def addToolchain(self, toolchain):
        for t in self.toolchains:
            if t.type==toolchain.type and t.arch==toolchain.arch and t.name==toolchain.name:
                raise Exception('Toolchain \'%s\'(%s) conflicts with %s(%s)' % (
                                toolchain, self.striptopdir(toolchain.source),
                                t, self.striptopdir(t.source))
                                )
        self.toolchains.append(toolchain)

    def findToolchains(self, arch, name=None):
        r = []

        for t in self.toolchains:
            localname = name
            if not localname:
                envvarname = 'EFIDROID_TOOLCHAIN_NAME_'+t.type.upper()
                if envvarname in os.environ:
                    localname = os.environ[envvarname]
            if not localname:
                localname = 'gcc6'

            if t.arch==arch and t.name==localname:
                r.append(t)

                if not t in self.toolchains_used:
                    self.toolchains_used.append(t)

        return r

    def getfname(self, path, absolute=False, otherspaces=[]):
        if not absolute:
            path = '$(TOP)/'+path
        r = self.globalvars.evaluate_str(path)
        for space in otherspaces:
            r = space.evaluate_str(r)

        VariableSpace.verify(r)
        return r

    def striptopdir(self, path):
        top = self.globalvars.get('TOP')+'/'
        if path.startswith(top):
            return path[len(top):]
        return path

    def __escape_value(self, s):
        s = s.replace('"', '\\"')
        return s

    def __generate_command_line(self, target, command, arch, toolchains):
        line = ''
        toolchainspaces = [t.toolchainvars for t in toolchains]

        for arg in command:
            if arg==Target.COMMAND_MAKE:
                arg = '$(MAKE)'
                line += arg+' '

            elif arg==Target.COMMAND_ENV:
                tmp = ' '

                # add target variables
                for name in target.vars.vars:
                    value = target.vars.vars[name]
                    tmp += name+'="'+self.__escape_value(value)+'" '

                # add toolchain variables
                for t in toolchains:
                    for name in t.toolchainvars.vars:
                        value = t.toolchainvars.vars[name]
                        tmp += name+'="'+self.__escape_value(value)+'" '

                line += tmp+' '

            else:
                if isinstance(arg, Target.Raw):
                    narg = ' '+arg.s+' '
                else:
                    narg = arg

                # add argument
                if narg in Target.OPERATORS or isinstance(arg, Target.Raw):
                    line += narg
                else:
                    line += '"'+self.__escape_value(narg)+'" '

        line = self.expandVariables(target, line, otherspaces=toolchainspaces)
        VariableSpace.verify(line)

        return line

    def __generate_target_commands(self, name, target):
        r = []
        arch = None
        toolchains = []

        # get arch
        if target.clazz!='host':
            arch = target.vars.get('MODULE_ARCH', throw=False)
            if not arch:
                arch = self.architectures[0]

            # get toolchains
            toolchains = self.findToolchains(arch)
            if arch!='host' and len(toolchains)<=0:
                raise Exception('no toolchains found for architecture %s' % (arch))

        if target.create_moduledir:
            cmd_mkdir = ['mkdir', '-p', '$(MODULE_OUT)']
            r.append(self.__generate_command_line(target, cmd_mkdir, arch, toolchains))

        for command in target.commands:
            r.append(self.__generate_command_line(target, command, arch, toolchains))

        return r

    @staticmethod
    def __makehelptext(targetname, text):
        return bldwht.replace('\033', '\\033')+targetname+': ' \
                        +txtrst.replace('\033', '\\033')+text.replace('\n', '\\n'+((len(targetname)+2)*' '))+'\\n'

    def generate_makefile(self, filename):
        makeout = StringIO()
        make = make_syntax.Writer(makeout)
        helptext = ''
        helptext_internal = ''

        # add force target
        make.comment('Used to force goals to build. Only use for conditionally defined goals.')
        make.target('FORCE')
        make.newline()

        # add targets
        for target in sorted(self.targets, key=lambda x: x.name):
            deps = target.dependencies
            commands = []

            target_arch = target.vars.get('MODULE_ARCH', throw=False)
            if (target_arch) and (not target_arch in self.architectures):
                continue

            if target.force:
                deps.append('FORCE')

            # generate commands
            if target.commands:
                commands = self.__generate_target_commands(target.name, target)

            compilationmessage = None
            if not target.silent:
                if target.name.endswith('_clean'):
                    compilationmessage = 'Cleaning '+target.name
                elif target.name.endswith('_distclean'):
                    compilationmessage = 'Dist-Cleaning '+target.name
                else:
                    compilationmessage = 'Compiling '+target.name
            if target.compilationmessage:
                compilationmessage = target.compilationmessage

            # create actual make target
            make.comment(self.striptopdir(target.source))
            make.target(target.name, commands, deps, target.phony, compilationmessage)
            make.newline()

            # add to help text
            nhelptext = Context.__makehelptext(target.name, target.description)
            if not target.internal:
                helptext += nhelptext
            helptext_internal += nhelptext

        # add additional help texts
        nhelptext = Context.__makehelptext('help', 'Show available targets')
        helptext += nhelptext
        helptext_internal += nhelptext
        helptext_internal += Context.__makehelptext('help-internal', 'Show available targets')

        # help target
        make.comment('HELP')
        make.target('help', 'echo -e \"'+helptext.replace('"', '\\"')+'\"', [], True, 'Generating Help')
        make.default(['help'])
        make.newline()

        # help target
        make.comment('HELP-INTERNAL')
        make.target('help-internal', 'echo -e \"'+helptext_internal.replace('"', '\\"')+'\"', [], True, 'Generating Help')
        make.newline()

        # check deps
        make.check_dependencies()

        # write makefile
        with open(filename, 'w') as f:
            f.write(makeout.getvalue())

        makeout.close()

    def prepare_targets(self):
        if len(self.architectures)>0:
            mainarch = self.architectures[0]
        else:
            mainarch = None

        for target in list(self.targets):
            if target.clazz=='host':
                continue
            if target.vars.get('MODULE_ARCH', throw=False):
                continue
            if target.clazz=='device':
                target.vars.set('MODULE_ARCH', mainarch)
                continue

            needs_alias = not ('$(MODULE_OUT)' in target.name or '$(MODULE_ARCH)' in target.name)

            # create architecture-specific targets
            for arch in self.architectures:
                nname = target.name
                if needs_alias:
                    nname = arch+'_'+nname

                ntarget = copy.deepcopy(target)
                ntarget.vars.set('MODULE_ARCH', arch)
                ntarget.name = nname
                if arch==mainarch and needs_alias:
                    ntarget.internal = True

                self.addTarget(ntarget)
                if target.name in self.cleantargets:
                    self.cleantargets.append(ntarget.name)
                if target.name in self.distcleantargets:
                    self.cleantargets.append(ntarget.name)

            # delete original target
            self.removeTarget(target)

            # create alias target
            if needs_alias:
                ntarget = Target()
                ntarget.name = target.name
                ntarget.source = target.source
                ntarget.description = target.description
                ntarget.silent = True
                ntarget.phony = True
                ntarget.internal = target.internal
                ntarget.clazz = target.clazz
                ntarget.is_archalias = True
                ntarget.dependencies = [mainarch+'_'+target.name]
                self.addTarget(ntarget)
                if target.name in self.cleantargets:
                    self.cleantargets.append(ntarget.name)
                if target.name in self.distcleantargets:
                    self.cleantargets.append(ntarget.name)

        for target in self.targets:
            # set CLASS_OUT variable
            arch = target.vars.get('MODULE_ARCH', throw=False)
            if target.clazz=='target' and arch:
                clazzname = target.clazz+'_'+arch
            else:
                clazzname = target.clazz
            target.vars.set('CLASS_OUT', '$('+clazzname.upper()+'_OUT)')

            # expand target name
            target.name = self.expandVariables(target, target.name)
            VariableSpace.verify(target.name)

        # clean target
        target = Target()
        target.name = 'clean'
        target.description = 'Clean all projects'
        target.compilationmessage = 'Cleaning all projects'
        target.phony = True
        target.clazz = 'host'
        target.dependencies = self.cleantargets
        self.addTarget(target)

        # distclean target
        # this should call he distclean targets but instead, we just remove the out directory
        target = Target()
        target.name = 'distclean'
        target.description = 'Dist-Clean all projects'
        target.compilationmessage = 'Dist-Cleaning all projects'
        target.phony = True
        target.clazz = 'host'
        target.commands = [
            ['rm', '-Rf', '$(OUT)'],
        ]
        self.addTarget(target)

    def create_target_variables(self):
        self.archvars = {}
        for arch in self.architectures:
            self.archvars[arch] = VariableSpace()

        for target in self.targets:
            if target.name.startswith('/'):
                continue

            targetname = target.name.replace('/', '_').replace('.', '_')
            if target.is_archalias:
                for arch in self.architectures:
                    # get arch target
                    archtarget_name = arch+'_'+target.name
                    archtarget = self.getTarget(archtarget_name)
                    if not archtarget:
                        raise Exception('can\'t find target '+archtarget_name)

                    clazzspace = self.getClassVariableSpace(archtarget)
                    if not clazzspace:
                        raise Exception('class variable space not found for target \'%s\'' % archtarget.name)

                    # set variables
                    for name in archtarget.vars.vars:
                        value = archtarget.vars.vars[name]
                        if name.startswith('MODULE_'):
                            name = name[7:]

                        value = archtarget.vars.evaluate_str(value)
                        clazzspace.set(targetname.upper()+'_'+name.upper(), value)
            else:
                clazzspace = self.getClassVariableSpace(target)
                if not clazzspace:
                    raise Exception('class variable space not found for target \'%s\'' % target.name)

                for name in target.vars.vars:
                    value = target.vars.vars[name]
                    if name.startswith('MODULE_'):
                        name = name[7:]

                    value = target.vars.evaluate_str(value)
                    clazzspace.set(targetname.upper()+'_'+name.upper(), value)

    def prepare_dependencies(self):
        for target in self.targets:
            ndeps = []
            for dep in target.dependencies:
                # expand variables
                dep = self.expandVariables(target, dep)
                VariableSpace.verify(dep)

                # this target does exist, use it
                if self.getTarget(dep):
                    ndep = dep
                elif self.getTarget(target.clazz+'_'+dep):
                    ndep = target.clazz+'_'+dep
                else:
                    raise Exception('Can\'t resolve dependeny %s for target %s with arch %s' % (dep, target.name, target.vars.get('MODULE_ARCH', throw=False)))
                deptarget = self.getTarget(ndep)

                # this target got aliased, so use the correct arch variant
                if deptarget.is_archalias and target.vars.get('MODULE_ARCH', throw=False):
                    ndep = target.vars.get('MODULE_ARCH', throw=False)+'_'+ndep
                ndeps.append(ndep)

            target.dependencies = ndeps

class INIParser:
    def __init__(self, context):
        self.context = context
        self.__sectionhandlers = {}

        self.registerSectionHandler('target', self.__default_parseSectionTarget)

    def registerSectionHandler(self, name, o):
        self.__sectionhandlers[name] = o

    def __default_parseSectionTarget(self, args):
        if not len(args.attributes)==1:
            raise Exception('Invalid section attributes in '+args.context.striptopdir(args.filename)+':'+args.section+' - '+args.attributes)
        if not args.config.has_option(args.section, 'type'):
            raise Exception('missing target type in '+args.context.striptopdir(args.filename)+':'+args.section)

        targettype = args.config.get(args.section, 'type')
        handler = args.context.moduleparser.getModuleHandler(targettype)

        if not handler:
            raise Exception('Unsupported target type \''+targettype+'\' in '+args.context.striptopdir(args.filename)+':'+args.section)

        mopts = {}
        for k,v in args.opts:
            mopts[k] = v
        for k,v in args.items:
            mopts[k] = v

        margs = Bunch()
        margs.context = args.context
        margs.parser = args.context.moduleparser
        margs.opts = mopts
        margs.filename = args.filename
        margs.moduledir = args.moduledir
        margs.moduleconfigdir = args.moduleconfigdir
        margs.targetname = args.attributes[0]

        if targettype=='autoconf':
            generator = ModuleParser.get_autoconf_generator(margs.moduledir)
            if not generator:
                raise Exception('no valid autoconf generator found in '+margs.moduledir)
            margs.filename = generator

        for clazz in args.context.moduleparser.getModuleClasses(margs):
            if not clazz in self.context.clazzes:
                continue
            margs.clazz = clazz
            handler(margs)

    def parseFile(self, filename, moduledir=None):
        config = ConfigParser.RawConfigParser(allow_no_value=True)
        config.optionxform = str
        dataset = config.read(filename)

        if len(dataset)!=1:
            raise Exception('Can\'t read config \''+filename+'\'')

        parseopts = {}
        if 'parseopts' in config.sections():
            for k,v in config.items('parseopts'):
                parseopts[k] = v

        for section in config.sections():
            nameparts = section.split('.')
            sectiontype = nameparts[0]

            if section=='parseopts':
                continue

            if not sectiontype in self.__sectionhandlers:
                raise Exception('Unsupported section type \''+sectiontype+'\' in '+self.context.striptopdir(filename))

            args = Bunch()
            args.context = self.context
            args.parser = self
            args.attributes = nameparts[1:]
            args.section = section
            args.items = config.items(section)
            args.opts = {}
            args.config = config
            args.filename = filename
            args.moduledir = moduledir
            args.moduleconfigdir = os.path.dirname(os.path.normpath(args.filename))
            self.__sectionhandlers[sectiontype](args)

        return parseopts


class ModuleParser:
    __cmake_generators = ['CMakeLists.txt']
    __make_generators = ['Makefile']
    __autoconf_generators = [
        'autogen.sh',
        'makeconf.sh',
        'bootstrap',
        'configure',
    ]

    def __init__(self, context):
        self.context = context
        self.__modulehandlers = {}

    def registerModuleHandler(self, name, o):
        self.__modulehandlers[name] = o

    def getModuleHandler(self, name):
        if name in self.__modulehandlers:
            return self.__modulehandlers[name]
        return None

    def getModuleClasses(self, args):
        clazzes = []
        if 'moduleclasses' in args.opts:
            clazzes = args.opts['moduleclasses'].split()
        else:
            for c in args.context.clazzes:
                if c=='device':
                    continue
                clazzes.append(c)
        return clazzes

    @staticmethod
    def __any_file_exists(path, namelist):
        for filename in namelist:
            if path:
                if os.path.exists(path+'/'+filename):
                    return path+'/'+filename
            else:
                if os.path.exists(filename):
                    return filename

        return None

    @staticmethod
    def get_autoconf_generator(path):
        return ModuleParser.__any_file_exists(path, ModuleParser.__autoconf_generators)

    def parseModule(self, path, configdir):
        parseopts = {}
        args = Bunch()
        dirname = os.path.basename(os.path.normpath(path))
        builddirconfig = [
            configdir+'/'+dirname+'/EFIDroid.ini',
            path+'/EFIDroid.ini',
        ]

        efidroidini = ModuleParser.__any_file_exists(None, builddirconfig)
        cmake = ModuleParser.__any_file_exists(path, ModuleParser.__cmake_generators)
        make = ModuleParser.__any_file_exists(path, ModuleParser.__make_generators)
        autoconf = ModuleParser.get_autoconf_generator(path)
        uefiinf = ModuleParser.__any_file_exists(path, [dirname+'.inf'])

        # parse EFIDroid.ini
        if efidroidini:
            parseopts = self.context.iniparser.parseFile(efidroidini, moduledir=path)
            if not (('extend' in parseopts) and (parseopts['extend']=='1')):
                return

        if cmake:
            moduletype = 'cmake'
            args.filename = cmake

        elif autoconf:
            moduletype = 'autoconf'
            args.filename = autoconf

        elif uefiinf:
            moduletype = 'uefiapp'
            args.filename = uefiinf

        elif make:
            moduletype = 'make'
            args.filename = make

        else:
            pr_warning('can\'t detect module type for \''+self.context.striptopdir(path)+'\'')
            return

        if not moduletype in self.__modulehandlers:
            raise Exception('Unsupported module type \''+moduletype+'\'')

        args.context = self.context
        args.parser = self
        args.moduledir = path
        args.opts = parseopts
        args.targetname = dirname
        args.moduleconfigdir = os.path.dirname(os.path.normpath(args.filename))

        if moduletype=='uefiapp':
            args.clazz = 'target'
            if args.clazz in self.context.clazzes:
                self.__modulehandlers[moduletype](args)
        else:
            for clazz in self.getModuleClasses(args):
                if not clazz in self.context.clazzes:
                    continue

                args.clazz = clazz
                self.__modulehandlers[moduletype](args)

class Target:
    COMMAND_MAKE = 0
    COMMAND_ENV = 1

    OPERATORS = ['&&', '||', ';', '(', ')']

    class Raw:
        def __init__(self, s):
            self.s = s

    def __init__(self):
        self.silent = False
        self.compilationmessage = None
        self.internal = False
        self.description = ''
        self.source = '<unknown>'
        self.vars = VariableSpace()
        self.commands = None
        self.dependencies = []
        self.clazz = None
        self.force = False
        self.phony = False
        self.create_moduledir = False
        self.name = None

        self.is_archalias = False

    def __str__(self):
        return self.__dict__.__str__()

    def __repr__(self):
        return self.__dict__.__repr__()

class ChecksumVerifier:
    def __init__(self, vars):
        if vars.has('sha256'):
            self.sum = vars.get('sha256')
            self.alg = 'sha256'
        elif vars.has('sha1'):
            self.sum = vars.get('sha1')
            self.alg = 'sha1'
        else:
            raise Exception()

    def calculate(self, filepath):
        h = hashlib.new(self.alg)

        with open(filepath, 'rb') as f:
            h.update(f.read())

        return h.hexdigest()

    def verify(self, filepath):
        return self.sum == self.calculate(filepath)

class Toolchain:
    def __init__(self, attributes, items):
        self.localvars = VariableSpace()
        self.toolchainvars = VariableSpace()
        self.type = attributes[0]
        self.arch = attributes[1]
        self.name = attributes[2]
        self.source = '<unknown>'
        self.variable_prefix = self.type.upper()+'_TARGET'

        # set local variables
        for (name, value) in items:
            self.localvars.set(name, value)

        # evaluate local variables
        var_path = self.localvars.evaluate_str(self.localvars.get('path'))
        var_name = self.localvars.evaluate_str(self.localvars.get('name'))
        var_prefix = self.localvars.evaluate_str(self.localvars.get('prefix'))

        # set toolchain variables
        self.toolchainvars.set(self.variable_prefix+'_PATH', var_path)
        self.toolchainvars.set(self.variable_prefix+'_NAME', var_name)
        self.toolchainvars.set(self.variable_prefix+'_PREFIX', var_prefix)

    def get_cksum_verifier(self):
        try:
            return ChecksumVerifier(self.localvars)
        except e:
            raise Exception('toolchain \'%s\' doesn\'t have a checksum' % str(self))

    def __str__(self):
        return '%s.%s.%s' % (self.type, self.arch, self.name)
