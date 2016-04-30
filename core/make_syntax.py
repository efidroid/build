#!/usr/bin/env python -B
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

class Writer(object):
    def __init__(self, output, width=78, hidecommands=True):
        self.output = output
        self.width = width
        self.hidecommands = hidecommands
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

        if phony:
            self._line('.PHONY: %s' % name)
        self._line('%s: %s' % (name,
                                ' '.join(deps)))

        prefix = ""
        if self.hidecommands:
            prefix = "@"

        if description:
            self.output.write('\t%s$$EFIDROID_SHELL -c \'echo -e "\\033[1;37m%s\\033[0m"\'\n' % (prefix, description))

        for line in commands:
            self.output.write('\t%s%s\n' % (prefix, line))

    def include(self, path):
        self._line('include %s' % path)

    def default(self, deps):
        self.dependencies('default', deps)

    def dependencies(self, name, deps):
        self._line('%s: %s' % (name, ' '.join(as_list(deps))))

    def _line(self, text, indent=0):
        """Write 'text' word-wrapped at self.width characters."""
        leading_space = '  ' * indent
        self.output.write(leading_space + text + '\n')

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
