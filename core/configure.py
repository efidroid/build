#!/usr/bin/python -B

# common imports
import ConfigParser
import os.path
import sys
import glob
import make_syntax
import os

# compatibility imports
try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

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
cfg = Bunch()

def pr_error(*args):
    print(bldred+" ".join(map(str,args))+txtrst)
def pr_info(*args):
    print(bldwht+" ".join(map(str,args))+txtrst)
def pr_warning(*args):
    print(bldylw+" ".join(map(str,args))+txtrst)
def pr_notice(*args):
    print(bldcyn+" ".join(map(str,args))+txtrst)
def pr_alert(*args):
    print(bldgrn+" ".join(map(str,args))+txtrst)

def setvar(name, value):
    cfg.variables[name] = value

def expandvars(string):
    # all variables got expanded already so this is much easier
    for k, v in cfg.variables.items():
        string = string.replace('$(%s)' % k, v)

    return string

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

def getvar(name):
    return cfg.variables[name]

def addhelp(name, text):
    cfg.helptext += bldwht.replace('\033', '\\e')+name+': '+txtrst.replace('\033', '\\e')+text.replace('\n', '\\n'+((len(name)+2)*' '))+'\\n'

def define_target_vars(name, projecttype):
    name_upper = name.upper()

    # set target variables            
    if projecttype=='target':
        setvar('TARGET_'+name_upper+'_OUT', getvar('TARGET_OUT')+'/'+name)
    elif projecttype=='host':
        setvar('HOST_'+name_upper+'_OUT', getvar('HOST_OUT')+'/'+name)

def register_library(name, projecttype, path, static=True):
    o = Bunch()
    o.projecttype = projecttype
    o.path = path
    o.static = static

    cfg.libs[name] = o

def toolchain_write_header(f):
    f.write('if(DEFINED CMAKE_TOOLCHAIN_READY)\n')
    f.write('\treturn()\n')
    f.write('endif()\n\n')

def toolchain_write_footer(f):
    f.write('# prevent multiple inclusion\n')
    f.write('set(CMAKE_TOOLCHAIN_READY TRUE)\n')
    
def gen_toolchains():
    if not os.path.isdir(getvar('TARGET_OUT')):
        os.makedirs(getvar('TARGET_OUT'))
    if not os.path.isdir(getvar('HOST_OUT')):
        os.makedirs(getvar('HOST_OUT'))

    fTarget = open(getvar('TARGET_OUT')+'/toolchain.cmake', 'w')
    fHost   = open(getvar('HOST_OUT')+'/toolchain.cmake', 'w')

    toolchain_write_header(fHost)
    toolchain_write_header(fTarget)

    for name, o in cfg.libs.items():
        f = None
        if o.projecttype == 'host':
            f = fHost
        elif o.projecttype == 'target':
            f = fTarget
        else:
            raise Exception('Invalid projecttype \''+o.projecttype+'\' for library \''+name+'\'!')

        linkage = 'STATIC'
        if not o.static:
            linkage = 'SHARED'

        f.write('add_library("'+name+'" '+linkage+' IMPORTED)\n')
        f.write('set_target_properties('+name+' PROPERTIES IMPORTED_LOCATION '+ expandvars(o.path)+')\n\n')

    toolchain_write_footer(fHost)
    toolchain_write_footer(fTarget)

    fTarget.close()
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

        elif section.startswith('target.'):
            targetname = section.split('.', 1)[1]
            targetname_id = targetname.upper()
            targettype = config.get(section, 'type')
            targetrule = targetname+'_rule'
            targetdir  = os.path.abspath(os.path.dirname(configfile))
            targetdeps = []
            targetcompilefn = 'EFIDroidCompile'
            targetforcecompile = True
            targetcategory = 'target'
            targetout = None
            outdir = targetname

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

            # add help entry
            if config.has_option(section, 'help'):
                addhelp(targetname, config.get(section, 'help'))

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
                make_add_target(configfile, targetname+'_clean', command+' Clean',\
                                description='Cleaning target \''+targetname+'\'')

                # add distclean target
                make_add_target(configfile, targetname+'_distclean', command+' DistClean', deps=targetdeps+[targetname+'_clean'],\
                                description='Dist-Cleaning target \''+targetname+'\'')

            else:
                raise Exception('Invalid target type \''+targettype+'\' in '+configfile)



            # set target variables            
            setvar(targetname_id+'_CONFIG_DIR', targetdir)
            define_target_vars(targetname, targetcategory)

        elif section.startswith('libraries.'):
            projecttype = section.split('.', 1)[1]

            for (name, value) in config.items(section):
                register_library(name, projecttype, value)

        else:
            raise Exception('Invalid section \''+section+'\' in '+configfile)

    cfg.make.newline()

def add_cmake_target(path, projecttype):
    cfg.make.comment(path)

    dirname = os.path.basename(os.path.normpath(path))
    targetname = projecttype+'_'+dirname
    targetdeps = [cfg.buildfname]
    cmakeargs = ''

    if projecttype == 'target':
        cmakeargs += ' -DCMAKE_C_COMPILER='+getvar('GCC_LINUX_GNUEABIHF')+'gcc'
        cmakeargs += ' -DCMAKE_CXX_COMPILER='+getvar('GCC_LINUX_GNUEABIHF')+'g++'
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('TARGET_OUT')+'/toolchain.cmake'
    elif projecttype == 'host':
        cmakeargs += ' -DCMAKE_TOOLCHAIN_FILE='+getvar('HOST_OUT')+'/toolchain.cmake'
    else:
        raise Exception('Invalid projecttype \''+projecttype+'\'')

    define_target_vars(dirname, projecttype)

    # add rule
    outdir = getvar(projecttype.upper()+'_'+dirname.upper()+'_OUT')
    make_add_target(path, targetname, [
        'mkdir -p \"'+outdir+'\"',
        'cd \"'+outdir+'\" && cmake '+cmakeargs+' '+os.path.abspath(path)+' && $(MAKE) VERBOSE=1'
    ], description='Compiling target \''+targetname+'\'', deps=targetdeps)
    addhelp(targetname, 'CMake Target')

    # add clean rule
    make_add_target(path, targetname+'_clean', [
        'cd \"'+outdir+'\" && $(MAKE) clean'
    ], description='Cleaning target \''+targetname+'\'', deps=targetdeps)

    # add distclean rule
    make_add_target(path, targetname+'_distclean', [
        'rm -Rf \"'+outdir+'\"'
    ], description='Dist-Cleaning target \''+targetname+'\'', deps=targetname+'_clean')

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

def main(argv):
    if len(argv)>=1:
        cfg.devicename = argv[0]
        pr_info('Configuring for %s' % cfg.devicename)
    else:
        cfg.devicename = None
        pr_info('Configuring for HOST')

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

    # open script configs
    try:
        os.makedirs(cfg.out)
    except:
        pass

    # set some common variables
    if cfg.devicename:
        tmp = cfg.devicename.split('/')
        if len(tmp) != 2:
            raise Exception('Invalid device name')

        # check if device exists
        if cfg.devicename and not os.path.isfile('device/'+cfg.devicename+'/config.ini'):
            raise Exception('Device does not exist')

        cfg.devicenamenice = cfg.devicename.replace('/','-')
        cfg.variableinc = cfg.out+'/variables_'+cfg.devicenamenice+'.mk'

        cfg.configinclude_name = cfg.out+'/config_'+cfg.devicenamenice
        cfg.buildfname = cfg.out+'/build_'+cfg.devicenamenice+'.mk'

        setvar('DEVICE', cfg.devicename)
        setvar('DEVICEVENDOR', tmp[0])
        setvar('DEVICENAME', tmp[1])
        setvar('TARGET_OUT', cfg.out+'/target/'+cfg.devicename)
    else:
        cfg.variableinc = cfg.out+'/variables_host.mk'
        cfg.configinclude_name = cfg.out+'/config_host'
        cfg.buildfname = cfg.out+'/build_host.mk'


    cfg.configinclude_sh = open(cfg.configinclude_name+'.sh', "w")
    cfg.configinclude_py = open(cfg.configinclude_name+'.py', "w")
    setvar('builddir', cfg.out)
    setvar('OUT', cfg.out)
    setvar('TOP', cfg.top)
    setvar('HOST_OUT', getvar('OUT')+'/host')
    setvar('MAKEFORWARD', getvar('HOST_OUT')+'/makeforward')
    setvar('MAKEFORWARD_PIPES', getvar('HOST_OUT')+'/makeforward_pipes')

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

    # add device config
    if cfg.devicename:
        parse_config('device/'+cfg.devicename+'/config.ini')

    # add build tasks
    for configfile in glob.glob('build/core/tasks/*.ini'):
        parse_config(configfile)

    # cmake needs the toolchain
    evaluatevars()

    # add modules
    for moduledir in glob.glob('modules/*'):
        dirname = os.path.basename(os.path.normpath(moduledir))
        moduleconfigfile = 'build/moduleconfigs/'+dirname+'/EFIDroid.ini'

        if os.path.isfile(moduleconfigfile):
            parse_config(moduleconfigfile, moduledir);

        if os.path.isfile(moduledir+'/CMakeLists.txt'):
            add_cmake_target(moduledir, 'target')
            add_cmake_target(moduledir, 'host')
        elif not os.path.isfile(moduleconfigfile):
            raise Exception('Unknown make system in '+moduledir+'\nYou can manually specify it in '+moduleconfigfile)

    # help target
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

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except:
        pr_error('Error: %s' % sys.exc_info()[1])
        raise
