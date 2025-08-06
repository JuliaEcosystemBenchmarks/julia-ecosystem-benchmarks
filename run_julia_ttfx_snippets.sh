#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 
export JULIA_NUM_THREADS=4

LOGS_DIR=$PWD/logs/Julia-TTFX-Snippets

./timetravel_setup.sh 2>$LOGS_DIR/${JEB_REGISTRY_DATE}_${JEB_JULIA_VERSION}_${JEB_HOSTNAME}.timetravel_setup.log

SNIPPETS_DIR=`mktemp -d`
echo "Working in $SNIPPETS_DIR"

cd $SNIPPETS_DIR
git clone https://github.com/tecosaur/Julia-TTFX-Snippets.git
cd Julia-TTFX-Snippets/tasks
GITHASH=`git rev-parse --short HEAD`
for SNIPPET in */*/*
do
    echo "[`date`] ##############################"
    echo "[`date`] # $SNIPPET - $JEB_JULIA_VERSION - $JEB_REGISTRY_DATE"
    mkdir -p $LOGS_DIR/$SNIPPET
    LOG_FILE=$LOGS_DIR/$SNIPPET/${GITHASH}_${JEB_REGISTRY_DATE}_${JEB_JULIA_VERSION}_${JEB_HOSTNAME}
    echo "[`date`] # Instantiating $SNIPPET on $JEB_JULIA_VERSION"
    env time -v nice -n -10 \
        julia +$JEB_JULIA_VERSION \
        --project=$SNIPPET \
	-e 'using Pkg; Pkg.instantiate()' 2>$LOG_FILE.instantiate.log || continue
    rm -rf $JULIA_DEPOT_PATH/compiled
    echo "[`date`] # Precompiling $SNIPPET on $JEB_JULIA_VERSION"
    env time -v \
        julia +$JEB_JULIA_VERSION \
        --project=$SNIPPET \
	-e 'using Pkg; @time @eval Pkg.precompile()' > $LOG_FILE.precompile 2>$LOG_FILE.precompile.log 
    echo "[`date`] # Running $SNIPPET on $JEB_JULIA_VERSION"
    env time -v \
        julia +$JEB_JULIA_VERSION \
        --project=$SNIPPET \
	$SNIPPET/task.jl > $LOG_FILE.task 2>$LOG_FILE.task.log
done




