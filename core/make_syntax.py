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

"""Python module for generating .mk files.
"""

import re
import textwrap
from utils import *

class Writer(object):
    def __init__(self, output, width=78, hidecommands=True, nodefaulttarget=False):
        self.output = output
        self.width = width
        self.hidecommands = hidecommands
        self.dependencies_list = {}
        self.targets_list = []
        if not nodefaulttarget:
            self.target('default', phony=True)
            self.newline()

    def newline(self):
        self.output.write('\n')

    def comment(self, text):
        for line in textwrap.wrap(text, self.width - 2):
            self.output.write('# ' + line + '\n')

    def variable(self, key, value, indent=0):
        if value is None:
            return
        if isinstance(value, list):
            value = ' '.join(filter(None, value))  # Filter out empty strings.
        self._line('%s := %s' % (key, value), indent)

    def target(self, name, commands=None, deps=None, phony=False, description=None):
        deps = as_list(deps)
        commands = as_command_list(commands)

        if name in self.targets_list:
            raise Exception('Duplicate target \''+name+'\'')

        if phony:
            self._line('.PHONY: %s' % name)
        self._line('%s: %s' % (name,
                                ' '.join(deps)))

        prefix = ""
        if self.hidecommands:
            prefix = "@"

        if description:
            self.output.write('\t%s$$EFIDROID_SHELL -c "echo -e \\\"\\033[1;37m%s\\033[0m\\\""\n' % (prefix, description.replace('"', '\\\\\\"')))

        for line in commands:
            self.output.write('\t%s%s\n' % (prefix, line))

        self.targets_list += [name]
        self.dependencies(name, deps, nocode=True)

    def include(self, path):
        self._line('include %s' % path)

    def default(self, deps):
        self.dependencies('default', deps)

    def dependencies(self, name, deps, nocode=False):
        depsarr = as_list(deps)

        # check if the target exists
        if not name in self.targets_list:
            if not (name=='clean' or name=='distclean'):
                raise Exception('target \''+name+'\' doesn\'t exist (yet)')

        # write dependency to makefile
        if not nocode:
            self._line('%s: %s' % (name, ' '.join(depsarr)))

        # add dependency to list
        if not name in self.dependencies_list:
            self.dependencies_list[name] = []
        self.dependencies_list[name] += depsarr

    def _line(self, text, indent=0):
        """Write 'text' word-wrapped at self.width characters."""
        leading_space = '  ' * indent
        self.output.write(leading_space + text + '\n')

    def check_dependencies(self):
        error = False
        for target in self.dependencies_list:
            if not target in self.targets_list:
                pr_error('defined dependencies for non-existend target \''+target+'\'')
                error = True

            for dep in self.dependencies_list[target]:
                if not dep in self.targets_list:
                    pr_error('target \''+target+'\' depends on non-existend target \''+dep+'\'')
                    error = True

        if error:
            pr_fatal('Dependency errors.')

    def close(self):
        self.output.close()


def as_list(input):
    if input is None:
        return []
    if isinstance(input, list):
        return input
    return [input]

def as_command_list(input):
    if input is None:
        return []
    if isinstance(input, list):
        return input
    return input.splitlines()
