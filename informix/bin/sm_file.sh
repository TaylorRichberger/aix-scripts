#!/bin/ksh

echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo "This operation will refresh the printing system smit screens"
echo "and relink the system queues to the new screens. To complete"
echo "the operation I will stop qdaemon and restart it after I am done.\n"
echo "Any job currently printing will start over from the begining.\n"
echo "If you want me to continue with this operation type YES in capital"
echo "letters, and hit <enter>. If not type NO and hit <enter>.\n"
echo "Shall I continue?"
while read QSTOP
do
	{
	if [[ -z $QSTOP ]] #tests for a null (just hit enter)
	then
		echo "\n"
	elif test $QSTOP = "NO"
	then
		echo "stopping with no change to smit queue screens"
		exit #exits this shell script
	elif test $QSTOP = "YES"
	then
		break #exits the while loop after the
	fi
	}
	echo "Please enter NO or YES"
done
echo "\n"
echo "Stopping qdaemon."
echo "\n"
stopsrc -cs qdaemon
echo "I will now copy backup smit screen files to the directory of:"
echo "/var/spool/lpd/pio/@local/smit."
echo "one moment please...\n"
sleep 5

cp /usr/lpp/printers.rte/inst_root/var/spool/lpd/pio/@local/smit/* /var/spool/lpd/pio/@local/smit

echo "Done with smit screen refresh.\n"
sleep 2
cd /var/spool/lpd/pio/@local/custom
echo "I will now link the currently existing queues on the system, with the"
echo "refreshed smit screens.\n"
sleep 3
for file in `ls`
do
	echo "Now linking queue and device $file"
	/usr/lib/lpd/pio/etc/piodigest $file
done
echo "\n"
echo "Starting qdaemon"
startsrc -s qdaemon
echo "\n"
echo "The print queue refresh/relink operation is complete. If you have"
echo "any questions or problems please call: 1-800-225-5249 (AIX SUPPORT)."
echo "Thank you for using AIX SUPPORT."
#End of script
