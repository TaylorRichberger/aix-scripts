#!/bin/sh
# Copyright © 2018 Absolute Performance, Inc.
# Written by Taylor C. Richberger <tcr@absolute-performance.com>
# This is proprietary software.  No warranty, explicit or implicit, provided.

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<HERE
$0 [options]
    -h  Show this help
HERE
}

getfield() {
  filename="${1:?Need to specify the filename}"
  field="${2:?Need to specify the field}"
  awk "-vfield=$field" '{if (field == $1) print $2}' "$filename"
}

credfile=/etc/storwize.pass
username=
password=

while getopts hu:p:c:C:d:v:m:P: opt; do
  case $opt in
    h)
      usage
      exit
      ;;
    u) username="$OPTARG" ;;
    p) password="$OPTARG" ;;
    c) credfile="$OPTARG" ;;
    C) certfile="$OPTARG" ;;
    d) disk="$OPTARG" ;;
    v) vgname="$OPTARG" ;;
    P) prevmount="$OPTARG" ;;
    m) mount="$OPTARG" ;;
    r) resthost="$OPTARG" ;;
    g) groupname="$OPTARG" ;;
    ?)
      usage
      exit 2
      ;;
  esac
done

echo mount: ${mount:?Mount must be set}
echo disk: ${disk:?Disk must be set}
echo vgname: ${vgname:?VG name must be set}
echo certfile: ${certfile:?Cert file must be set}
echo resthost: ${resthost:?REST host must be set}
echo groupname: ${groupname:?FC Consistency Group Name must be set}

if [ -z "$username"] || [ -z "$password" ]; then
  username="$(getfield "$credfile" username)"
  password="$(getfield "$credfile" password)"
fi

if [ -z "$username"] || [ -z "$password" ]; then
  die 'Username or password not set'
fi

umount -f "$mount"
varyoffvg "$vgname"
exportvg "$vgname"

# TODO: make sure this works
curl --fail --cacert "$certfile" -u "${username}:${password}" -G -d prep -d "fc_consist_group_name=${groupname}" "https://${resthost}/api/fcconsistgrp/start/" || die 'could not start consistency group'

chdev -l "$disk" -a pv=clear
recreatevg -y "$vgname" -L"$mount" "$disk"

if [ -n "$prevmount" ]; then
  chfs -m"$mount" "$prevmount"
end

fsck -y "$mount"
mount "$mount"
