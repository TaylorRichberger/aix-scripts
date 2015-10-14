#!/usr/bin/python
import sys
import re
import pprint
import __future__

def Usage():
    print(sys.argv[0] + " {input database} {symlink list}")

if len(sys.argv) != 3:
    Usage()
    exit(1)

fileP = re.compile(r'^(\S+?):$')
attribP = re.compile(r'^\t(\S+?)\s*=\s*(.*)$')


pathlist = list()
files = dict()
cur = None

database = open(sys.argv[1], 'r')

# Extracts current database into structure
for line in database.readlines():
    stripline = line.rstrip()

    fileM = fileP.match(stripline)
    attribM = attribP.match(stripline)
    if fileM:
        pathlist.append(fileM.group(1))

        if fileM.group(1) not in files:
            files[fileM.group(1)] = dict()

        cur = files[fileM.group(1)]
    elif attribM:
        if attribM.group(1) not in cur:
            cur[attribM.group(1)] = set()

        if len(attribM.group(2)) > 1:
            cur[attribM.group(1)].update(attribM.group(2).split(','))

database.close()

links = open(sys.argv[2], 'r')

# Extracts current database into structure
for line in links.readlines():
    stripline = line.strip()
    path, link = stripline.split(' ')
    if path in files:
        if 'symlinks' not in files[path]:
            files[path]['symlinks'] = set()

        files[path]['symlinks'].add(link)

links.close()

for path in pathlist:
    f = files[path]

    print(path + ":")
    for k, v in f.items():
        print('\t' + k + " = " + ','.join(v))
    print()
