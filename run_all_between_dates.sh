#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 
export JULIA_NUM_THREADS=4

./hostdescription.sh


if [ -z "$JEB_JUMP_DAY" ]; then
    echo "[`date`] # JEB_JUMP_DAY not set; setting it to default"
    JEB_JUMP_DAY=1
fi
echo "[`date`] # JEB_JUMP_DAY=$JEB_JUMP_DAY"

count=0
while true
do
    export JEB_REGISTRY_DATE=`date -Idate -d "$JEB_REGISTRY_START_DATE + $count days"` 

    regdatesec=$(date -d $JEB_REGISTRY_DATE +%s)
    enddatesec=$(date -d $JEB_REGISTRY_END_DATE +%s)
    if [ $regdatesec -ge $enddatesec ];
    then
        break
    fi

    ./run_julia_ttfx_snippets.sh

    count=$(( $count + $JEB_JUMP_DAY ))
done




