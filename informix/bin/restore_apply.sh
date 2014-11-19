#!/bin/ksh
# IDS restore level-0 backup and apply logs to DR system
# 2009-10-29 BWS/API
export LANG=en_US
/API/bin/burest --restore 
[ $? -ne 0 ] && exit $?
/API/bin/logapply --apply --nodelete
[ $? -ne 0 ] && exit $?
# apply any new logs
/API/bin/logapply --apply --nodelete
exit $?
