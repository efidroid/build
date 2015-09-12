#!/usr/bin/env python
# Copyright (C) 2012-2013, The CyanogenMod Project
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

from __future__ import print_function

import base64
import json
import netrc
import os
import re
import sys
try:
  # For python3
  import urllib.error
  import urllib.parse
  import urllib.request
except ImportError:
  # For python2
  import imp
  import urllib2
  import urlparse
  urllib = imp.new_module('urllib')
  urllib.error = urllib2
  urllib.parse = urlparse
  urllib.request = urllib2

from xml.etree import ElementTree

device = sys.argv[1];

if len(sys.argv) > 2:
    depsonly = sys.argv[2]
else:
    depsonly = None

if not depsonly:
    print("Device %s not found. Attempting to retrieve device repository from EFIDroid Github (http://github.com/efiroid)." % device)


#repositories = []

try:
    authtuple = netrc.netrc().authenticators("api.github.com")

    if authtuple:
        githubauth = base64.encodestring('%s:%s' % (authtuple[0], authtuple[2])).replace('\n', '')
    else:
        githubauth = None
except:
    githubauth = None

def add_auth(githubreq):
    if githubauth:
        githubreq.add_header("Authorization","Basic %s" % githubauth)

if not depsonly:
    githubreq = urllib.request.Request("https://api.github.com/repos/efidroid/device/branches/%s" % device)
    add_auth(githubreq)
    try:
        result = json.loads(urllib.request.urlopen(githubreq).read().decode())
    except urllib.error.URLError:
        print("Device %s not found on EFIDroid Github" % device)
        sys.exit()
    except ValueError:
        print("Failed to parse return data from GitHub")
        sys.exit()
    if not result.get('name', []):
        print("Device %s not found on EFIDroid Github" % device)
        sys.exit()

local_manifests = r'.repo/local_manifests'
if not os.path.exists(local_manifests): os.makedirs(local_manifests)

def exists_in_tree(lm, repository, revision):
    for child in lm.getchildren():
        if child.attrib['name'].endswith(repository) and child.attrib['revision']==revision:
            return True
    return False

# in-place prettyprint formatter
def indent(elem, level=0):
    i = "\n" + level*"  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent(elem, level+1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

def get_default_revision():
    m = ElementTree.parse(".repo/manifest.xml")
    d = m.findall('default')[0]
    r = d.get('revision')
    return r.replace('refs/heads/', '').replace('refs/tags/', '')

def get_from_manifest(devicename):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if re.search("android_device_.*_%s$" % device, localpath.get("name")):
            return localpath.get("path")

    # Devices originally from AOSP are in the main manifest...
    try:
        mm = ElementTree.parse(".repo/manifest.xml")
        mm = mm.getroot()
    except:
        mm = ElementTree.Element("manifest")

    for localpath in mm.findall("project"):
        if re.search("android_device_.*_%s$" % device, localpath.get("name")):
            return localpath.get("path")

    return None

def is_in_manifest(projectname):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if localpath.get("name") == projectname:
            return 1

    ## Search in main manifest, too
    try:
        lm = ElementTree.parse(".repo/manifest.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if localpath.get("name") == projectname:
            return 1

    return None

def add_to_manifest(repositories, fallback_branch = None):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for repository in repositories:
        repo_name = repository['repository']
        repo_target = repository['target_path']
        repo_revision = repository.get('revision', 'master')
        if exists_in_tree(lm, repo_name, repo_revision):
            print('efidroid/%s already exists' % (repo_name))
            continue

        print('Adding dependency: efidroid/%s -> %s' % (repo_name, repo_target))
        project = ElementTree.Element("project", attrib = { "path": repo_target,
            "remote": "github", "name": "efidroid/%s" % repo_name })

        if 'branch' in repository:
            project.set('revision',repository['branch'])
        elif fallback_branch:
            print("Using fallback branch %s for %s" % (fallback_branch, repo_name))
            project.set('revision', fallback_branch)
        else:
            print("Using default branch for %s" % repo_name)

        lm.append(project)

    indent(lm, 0)
    raw_xml = ElementTree.tostring(lm).decode()
    raw_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + raw_xml

    f = open('.repo/local_manifests/roomservice.xml', 'w')
    f.write(raw_xml)
    f.close()

def fetch_dependencies(repo_path, fallback_branch = None):
    print('Looking for dependencies')
    dependencies_path = repo_path + '/efidroid.dependencies'
    syncable_repos = []

    if os.path.exists(dependencies_path):
        dependencies_file = open(dependencies_path, 'r')
        dependencies = json.loads(dependencies_file.read())
        fetch_list = []

        for dependency in dependencies:
            if not is_in_manifest("efidroid/%s" % dependency['repository']):
                fetch_list.append(dependency)
                syncable_repos.append(dependency['target_path'])

        dependencies_file.close()

        if len(fetch_list) > 0:
            print('Adding dependencies to manifest')
            add_to_manifest(fetch_list, fallback_branch)
    else:
        print('Dependencies file not found, bailing out.')

    if len(syncable_repos) > 0:
        print('Syncing dependencies')
        os.system('repo sync %s' % ' '.join(syncable_repos))

    for deprepo in syncable_repos:
        fetch_dependencies(deprepo)

def has_branch(branches, revision):
    return revision in [branch['name'] for branch in branches]

if depsonly:
    repo_path = get_from_manifest(device)
    if repo_path:
        fetch_dependencies(repo_path)
    else:
        print("Trying dependencies-only mode on a non-existing device tree?")

    sys.exit()

else:
    print("Found device: %s" % device)

    repo_path = "device/%s" % (device)    
    adding = {'repository':'device','target_path':repo_path, 'branch':device}
    add_to_manifest([adding])

    print("Syncing repository to retrieve project.")
    os.system('repo sync %s' % repo_path)
    print("Repository synced!")

    fetch_dependencies(repo_path)
    print("Done")
    sys.exit()
