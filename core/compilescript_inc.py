import sys
from utils import *

def setvar(name, value):
    f = open(OUT+'/buildtime_variables.sh', 'a')
    f.write('export '+name+'="'+value+'"\n')
    f.close()

    f = open(OUT+'/buildtime_variables.py', 'a')
    f.write(name+' = "'+value+'"\n')
    f.close()

    globals()[name] = value
