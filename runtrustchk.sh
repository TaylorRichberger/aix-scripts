#!/bin/sh

trustchk -n ALL 2>&1

STATUS=$?

if [ "$STATUS" -ne 0 ]; then
    echo "Problem: trustchk exited with status $STATUS"
fi
