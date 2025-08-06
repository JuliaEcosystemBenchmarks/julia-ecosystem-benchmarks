#!/usr/bin/env sh

mkdir -p logs/hostdescription
LOGFILE=logs/hostdescription/`date -Idate`_$JEB_HOSTNAME

echo uname -a > $LOGFILE
uname -a >> $LOGFILE
echo hostname >> $LOGFILE
hostname >> $LOGFILE
echo versioninfo >> $LOGFILE
juliaup add lts
julia +lts -e "using InteractiveUtils; versioninfo(verbose=true)" >> $LOGFILE
