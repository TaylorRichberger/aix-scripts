#!/bin/sh
# Copyright © 2018 Absolute Performance, Inc.
# Written by Taylor C. Richberger <tcr@absolute-performance.com>
# This is proprietary software.  No warranty, explicit or implicit, provided.

log() {
  now=$(date +'%Y-%m-%d %H:%M:%S')
  echo "INFO [$now]: $*"
}

die() {
  now=$(date +'%Y-%m-%d %H:%M:%S')
  echo "ERROR [$now]: $*" >&2
  if [ -n "$dbresume" ]; then
    log 'Emergency resuming DB'
    eval "$dbresume"
  fi
  exit 1
}

usage() {
  cat <<HERE
$0 [options]
    -h              Show this help
    -C [certfile]   The certificate file for the storwizerest host
    -P [command]    The db pause command
    -R [command]    The db resume command
    -c [file]       The credentials file, which are used to authenticate against the REST server
    -f [group]      The FlashCopy consistency group name
    -r [hostname]   The REST hostname; should match the certificate CN
HERE
}

while getopts hC:P:R:c:f:r: opt; do
  case $opt in
    h)
      usage
      exit
      ;;
    C) certfile="$OPTARG" ;;
    P) dbpause="$OPTARG" ;;
    R) dbresume="$OPTARG" ;;
    c) credentials="$OPTARG" ;;
    f) fcname="$OPTARG" ;;
    r) resthost="$OPTARG" ;;
    ?)
      usage
      exit 2
      ;;
  esac
done

check_set() {
  if [ -z "$1" ]; then
    die "$2"
  fi
}

check_set "$certfile" 'certfile must be set'
check_set "$credentials" 'credentials must be set'
check_set "$fcname" 'fcname must be set'
check_set "$resthost" 'resthost must be set'

export JBCRELEASEDIR=/jbase/cutools
export JBCGLOBALDIR=$JBCRELEASEDIR
export JBCJREDIR=$JBCRELEASEDIR/java/jre
export JBCJRELIB=$JBCRELEASEDIR/java/JBCJRELIB:$JBCRELEASEDIR/java/jvmlib
export PATH=$JBCRELEASEDIR/bin:$JBCRELEASEDIR/config:$PATH
export LD_LIBRARY_PATH=$JBCRELEASEDIR/lib:$JBCJRELIB:/usr/lib:$LD_LIBRARY_PATH
export PATH=$JBCRELEASEDIR/bin:$JBCJREDIR/bin:$PATH

if [ -n "$dbpause" ]; then
  log 'Pausing DB'
  eval "$dbpause"
fi


log 'Trying to stop the snap copy if it is in process.'
curl --cacert "$certfile" --netrc-file "$credentials" -G -d "fc_consist_group_name=${fcname}" "https://${resthost}/api/fcconsistgrp/stop/" >/dev/null 2>&1

log 'Syncing disks and sleeping'
sync
sleep 5

log 'Starting the snapshot'
curl --fail --cacert "$certfile" --netrc-file "$credentials" -G -d prep -d "fc_consist_group_name=${fcname}" "https://${resthost}/api/fcconsistgrp/start/" || die 'Could not start consistency group'

if [ -n "$dbresume" ]; then
  log 'Resuming DB'
  eval "$dbresume"
fi

log "Finished making point-in-time snapshot"
