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
    -M [mount]      The temporary mount location, where the LV will be created before remounting it
    -P [command]    The db pause command
    -R [command]    The db resume command
    -c [file]       The credentials file, which are used to authenticate against the REST server
    -d [disk]       The disk to use
    -f [group]      The FlashCopy consistency group name
    -m [mount]      The final mount location (usually data2)
    -r [hostname]   The REST hostname; should match the certificate CN
    -v [group]      The volume group, which will be removed and recreated during the process of this command
HERE
}

while getopts hC:M:P:R:c:d:f:m:r:v: opt; do
  case $opt in
    h)
      usage
      exit
      ;;
    C) certfile="$OPTARG" ;;
    M) tempmount="$OPTARG" ;;
    P) dbpause="$OPTARG" ;;
    R) dbresume="$OPTARG" ;;
    c) credentials="$OPTARG" ;;
    d) disk="$OPTARG" ;;
    f) fcname="$OPTARG" ;;
    m) mount="$OPTARG" ;;
    r) resthost="$OPTARG" ;;
    v) vgname="$OPTARG" ;;
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
check_set "$tempmount" 'tempmount must be set'
check_set "$credentials" 'credentials must be set'
check_set "$disk" 'disk must be set'
check_set "$fcname" 'fcname must be set'
check_set "$mount" 'mount must be set'
check_set "$resthost" 'resthost must be set'
check_set "$vgname" 'vgname must be set'

tempdata="$tempmount/data"

export JBCRELEASEDIR=/jbase/cutools
export JBCGLOBALDIR=$JBCRELEASEDIR
export JBCJREDIR=$JBCRELEASEDIR/java/jre
export JBCJRELIB=$JBCRELEASEDIR/java/JBCJRELIB:$JBCRELEASEDIR/java/jvmlib
export PATH=$JBCRELEASEDIR/bin:$JBCRELEASEDIR/config:$PATH
export LD_LIBRARY_PATH=$JBCRELEASEDIR/lib:$JBCJRELIB:/usr/lib:$LD_LIBRARY_PATH
export PATH=$JBCRELEASEDIR/bin:$JBCJREDIR/bin:$PATH

log 'Removing mount and destroying VG'

umount -f "$mount"
varyoffvg "$vgname"
exportvg "$vgname"

if [ -n "$dbpause" ]; then
  log 'Pausing DB'
  eval "$dbpause"
fi


log 'Trying to stop the snap copy if it is in process.'
curl --cacert "$certfile" --netrc-file "$credentials" -G -d "fc_consist_group_name=${fcname}" "https://${resthost}/api/fcconsistgrp/stop/" >/dev/null 2>&1

log 'Starting the snapshot'
curl --fail --cacert "$certfile" --netrc-file "$credentials" -G -d prep -d "fc_consist_group_name=${fcname}" "https://${resthost}/api/fcconsistgrp/start/" || die 'Could not start consistency group'
if [ -n "$dbresume" ]; then
  log 'Resuming DB'
  eval "$dbresume"
fi

log 'Recreating the vg and mounting it'
chdev -l "$disk" -a pv=clear || die 'Could not chdev'
recreatevg -y "$vgname" -l/etc/"$vgname".map -L"$tempmount" "$disk" || die 'Could not createvg'
chfs -m"$mount" "$tempdata" || die 'Failed chfs'
fsck -y "$mount" || die 'Failed fsck'
mount "$mount" || die 'Could not mount'
