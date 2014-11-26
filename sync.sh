#!/bin/sh

if [ $# -ne 1 ]
then
    echo "Must take 1 argument: a production server to sync from"
fi

PROD="$1"

echo "INFO: Starting sync from $PROD"
echo "INFO: Syncing user home directories"
rsync -e ssh -avzu "$PROD":/Medic/usr /Medic

mkdir -p /tmp/usersync/security

echo "INFO: Syncing user files locally"
rsync -e ssh -avzu "$PROD":'/etc/group /etc/passwd' /tmp/usersync
rsync -e ssh -avzu "$PROD":'/etc/security/group /etc/security/passwd /etc/security/limits /etc/security/.ids /etc/security/environ /etc/security/.profile' /tmp/usersync/security

echo "INFO: Fixing groups file"
/API/bin/mergegroups -i /tmp/usersync/group -o /tmp/usersync/group -s 1500

echo "INFO: Backing up local files"
tar -cf- /etc/group /etc/passwd /etc/security/group /etc/security/passwd /etc/security/limits /etc/security/.ids /etc/security/environ /etc/security/.profile | gzip -c - > /$(hostname)-userbackup.tar.gz

rsync -avzu /tmp/usersync/* /etc

echo "INFO: Taking printers without backup"
rsync -e ssh -avzu "$PROD":/etc/qconfig /etc

echo "INFO: Refreshing printer config"
enq -d

echo "INFO: Syncing printer files"
rsync -e ssh -avzu "$PROD":'/var/spool/lpd/pio/@local/custom /var/spool/lpd/pio/@local/dev /var/spool/lpd/pio/@local/ddi' '/var/spool/lpd/pio/@local'

echo "INFO: Backing up and syncing hosts file"
cp /etc/hosts /etc/$(hostname)-hosts.backup
rsync -e ssh -avzu "$PROD":/etc/hosts /etc

echo "INFO: Fixing printers"
/bin/sh <<"HERE"
cp /usr/lpp/printers.rte/inst_root/var/spool/lpd/pio/@local/smit/* \
   /var/spool/lpd/pio/@local/smit
   
cd /var/spool/lpd/pio/@local/custom
chmod 775 /var/spool/lpd/pio/@local/custom
for FILE in `ls`
do
    chmod 664 $FILE
    QNAME=`echo $FILE | cut -d':' -f1`
    DEVICE=`echo $FILE | cut -d':' -f2`
    chvirprt -q $QNAME -d $DEVICE
done
HERE

echo "INFO: Sync Finished"
