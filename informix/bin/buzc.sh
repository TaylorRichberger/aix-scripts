#!/bin/ksh
# zip IDS levl-0 backup and copy to DR system
# 2009-10-28 BWS/API
/API/bin/zipbkup
[ $? -ne 0 ] && exit $?
LANG=en_US /API/bin/bucopy --copy
exit $?
