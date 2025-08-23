#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 
export JULIA_NUM_THREADS=4

./hostdescription.sh

while true
do
    juliaup update
    CURRENT_V=1.$(juliaup list | grep "release " | cut -d. -f2-3 | cut -d+ -f1)
    CURRENT_DATE=`date -Idate`
    for V in lts release $CURRENT_V alpha nightly
    do
        juliaup add $V
        juliaup update
        export JEB_REGISTRY_DATE=$CURRENT_DATE
        export JEB_JULIA_VERSION=$V
        echo "[`date`] running TTFX Snippets on $JEB_JULIA_VERSION"
        ./run_julia_ttfx_snippets.sh
    done

    git add logs
    git stash push --staged
    git fetch
    git pull
    git checkout jeb_logs
    git pull
    git stash pop
    git add logs
    git commit -m "daily logs $CURRENT_V $CURRENT_DATE"
    git checkout master

    julia +release --project=. -tauto,auto -e "using Pkg; Pkg.instantiate(); Pkg.update()"
    julia +release --project=. -tauto,auto ttfx_snippets_gather_data.jl
    julia +release --project=. -tauto,auto ttfx_snippets_vis.jl
    git add plots
    git stash push --staged
    git fetch
    git pull
    git checkout jeb_logs
    git pull
    rm -r plots/Julia-TTFX-Snippets/*
    git stash pop
    git add plots
    git commit -m "daily plots $CURRENT_V $CURRENT_DATE"
    git checkout master

    CURRENT_TIME=$(date +%s)
    TARGET_TIME=$(date -d "$CURRENT_DATE + 1 days" +%s)
    SLEEP_SECS=$(echo "$TARGET_TIME - $CURRENT_TIME" | bc)
    echo "[`date`] entering sleep for $SLEEP_SECS seconds"
    sleep $SLEEP_SECS
    sleep 600
done
