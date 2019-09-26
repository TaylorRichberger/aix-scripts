#!/usr/bin/python3
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>. 

'''os400pwgen.py: generate secure as possible level-0 passwords for as400 users'''

import string
import random

sets = [set(string.ascii_uppercase), set(string.digits), set('$@#_')]
newset = set()

output = []

rand = random.SystemRandom()

# This is done by first taking a random item from each set and putting it into
# the output, then removing it, and then adding the set to the full list to be
# sampled.  We do this to have a full password with at least one element from
# each set, and no repeating characters.  This is, in fact, less secure, but
# password policies demand it, annoyingly.
for s in sets:
    item = rand.sample(s, 1)[0]
    s.remove(item)
    output.append(item)
    newset.update(s)

output.extend(rand.sample(newset, 7))

rand.shuffle(output)

print(''.join(output))
