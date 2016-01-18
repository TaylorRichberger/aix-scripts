#!/usr/bin/python3
# To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>. 

'''os400pwgen.py: generate secure as possible level-0 passwords for as400 users'''

import string
import random

sets = [set(string.ascii_uppercase), set(string.digits), set('$@#_')]
newset = set()

output = []

rand = random.SystemRandom()

for i in range(0, 3):
    s = sets[i]
    item = rand.sample(s, 1)[0]
    s.remove(item)
    output.append(item)
    newset.update(s)

while len(output) < 10:
    item = rand.sample(newset, 1)[0]
    newset.remove(item)
    output.append(item)

print(''.join(output))
