#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 
export JULIA_NUM_THREADS=4

./hostdescription.sh

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

    count=$(( $count + 1 ))
done




