#!/bin/bash

DATE=`date +%Y%m%d`
GZIP=--best; export GZIP
TAR=/bin/tar
TAPE=/dev/tape
dow=`date +%w`

# Default root for backup configs
ROOTDIR=$PWD
ROOTDIR=${1:-$ROOTDIR}
UNMOUNT=${2:-false}

CONFIGDIR=${ROOTDIR}/conf/
CONFIGFILE=${CONFIGDIR}/settings
LISTDIR=${ROOTDIR}/paths/

EMAILSUBJ="Finished backup: ${SRCDIR}"
EMAILMSG="/tmp/message.txt"

if [ ! -d $CONFIGDIR ]; then
    echo "This doesn't seem to be a backup root, $CONFIGDIR doesn't exist, exiting"
    exit 1
fi

if [ ! -e $CONFIGFILE ]; then
    echo "$CONFIGFILE doesn't exist, I don't have any paths, exiting"
    exit 1
fi

if [ ! "$(ls -A $LISTDIR)" ]; then
    echo "$LISTDIR is empty, exiting"
    exit 1
fi

. $CONFIGFILE

# Set backupdir
LOGDIR=$BACKUPDIR/logs/
echo "Logging to $LOGDIR"

echo "Dumping running settings"
echo $SRCDIR
echo $BACKUPDIR
echo $ROOTDIR
echo $CONFIGDIR
echo $CONFIGFILE
echo $LOGDIR
echo $UNMOUNT
echo

# If the log directory doesn't exist, create it
if [ ! -d $LOGDIR ]; then
    echo "Making log directory $LOGDIR"
    mkdir -p $LOGDIR
fi

cd $LISTDIR

for d in *; do

    echo $d | grep "exclude$"
    if [[ $? -eq 0 ]]; then
	continue
    fi

    echo $d | grep "path$"
    if [[ $? -eq 0 ]]; then
	continue
    fi

    echo $d | grep "~$"
    if [[ $? -eq 0 ]]; then
	continue
    fi

    # Do direct rsync
    echo; date
    echo "Mirroring (direct) $d..."

    if [ -f $LISTDIR/$d.exclude ]; then
	echo "found excludes for $d"
	excludes="--exclude-from $LISTDIR/$d.exclude"
    else
	# Ensure we don't have one set from the last loop
	unset excludes
    fi

    if [ -f $LISTDIR/$d.path ]; then
	echo "found path for $d"
	read -r ALTPATH <$LISTDIR/$d.path
	WORKINGDIR=$ALTPATH
    else
	WORKINGDIR=$SRCDIR
    fi
    
    if [ -f $LOGDIR/rsync.$d.$DATE.log.gz ]; then
      echo "  Backup exists, aborting!"
      continue
    fi

    if [ -x $CONFIGDIR/$d-predump ]; then
      echo "  running predump script..."
      $CONFIGDIR/$d-predump
    fi

    echo "/usr/bin/rsync -av --delete --safe-links $excludes $WORKINGDIR/$d $BACKUPDIR"
    /usr/bin/rsync -av --delete --safe-links $excludes $SRCDIR/$d $BACKUPDIR >$LOGDIR/rsync.$d.$DATE.log

    echo "  compressing log file..."
    gzip -9v $LOGDIR/rsync.$d.$DATE.log

    if [ -x $CONFIGDIR/config/$d-postdump ]; then
      echo "  running postdump script..."
      $CONFIGDIR/config/$d-postdump
    fi

done

# Clean up

echo "  cleaning up old archives..."
find $LOGDIR -name rsync.\* -mtime +60 -ls -exec rm -f {} \;

# Echo how much space is left
df -h $BACKUPDIR

# Only send an email if a destination has been set
if [ -z ${EMAILTO+x} ]; then
    echo "Skipping email"
else
    # Sending completion email
    echo "Sending completion email."

    echo "Finished backup of $SRCDIR to USB $BACKUPDIR" >$EMAILMSG
    echo >>$EMAILMSG
    echo `ls ${BACKUPDIR}` >>$EMAILMSG
    echo >>$EMAILMSG
    df -h ${BACKUPDIR} >>$EMAILMSG
    echo >>$EMAILMSG

    /usr/bin/mail -s "$EMAILSUBJ" "$EMAILTO" <$EMAILMSG
fi

# Unmount the file system when we're done, if requested
cd -
sync

if [[ "$UNMOUNT" == "true"]]; then
    echo "Unmounting backup directory $BACKUPDIR"
    umount -v $BACKUPDIR &>> $EMAILMSG
fi

