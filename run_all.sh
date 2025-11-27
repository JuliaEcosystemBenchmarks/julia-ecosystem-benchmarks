#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 
export JULIA_NUM_THREADS=4

VERSIONS="\
1.8.0 2022-08-20 2022-09-10
1.8.1 2022-09-10 2022-09-30
1.8.2 2022-09-30 2022-11-20
1.8.3 2022-11-20 2022-12-30
1.8.4 2022-12-30 2023-01-10
1.8.5 2023-01-10 2023-05-10
1.9.0 2023-05-10 2023-06-10
1.9.1 2023-06-10 2023-07-10
1.9.2 2023-07-10 2023-08-30
1.9.3 2023-08-30 2023-11-20
1.9.4 2023-11-20 2023-12-30
1.10.0 2023-12-30 2024-02-20
1.10.1 2024-02-20 2024-03-10
1.10.2 2024-03-10 2024-05-10
1.10.3 2024-05-10 2024-06-10
1.10.4 2024-06-10 2024-08-30
1.10.5 2024-08-30 2024-10-10
1.11.0 2024-10-10 2024-10-20
1.11.1 2024-10-20 2024-12-10
1.11.2 2024-12-10 2025-01-30
1.11.3 2025-01-30 2025-03-20
1.11.4 2025-03-20 2025-04-20
1.11.5 2025-04-20 2025-07-20
1.11.6 2025-07-20 2025-09-20
1.11.7 2025-09-20 2025-10-15
1.12.0 2025-10-15 2025-10-25
1.12.1 2025-10-25 2025-11-22
1.12.2 2025-11-22 2025-11-27
"

./hostdescription.sh

for L in `echo "${VERSIONS}" | tr " " "_" | tr "\n" " "`
do
    export JEB_JULIA_VERSION=`echo $L | cut -d"_" -f1`
    export JEB_REGISTRY_START_DATE=`echo $L | cut -d"_" -f2`
    export JEB_REGISTRY_END_DATE=`echo $L | cut -d"_" -f3`

    if [ -z "$JEB_THRESHOLD_DATE" ]; then
        JEB_THRESHOLD_DATE="2010-01-01"
    fi
    thrdatesec=$(date -d $JEB_THRESHOLD_DATE +%s)
    enddatesec=$(date -d $JEB_REGISTRY_END_DATE +%s)
    startdatesec=$(date -d $JEB_REGISTRY_START_DATE +%s)
    if [ $thrdatesec -ge $enddatesec ];
    then
        echo "[`date`] # SKIPPING $JEB_JULIA_VERSION DUE TO DATE THRESHOLD "
        continue
    fi
    if [ $thrdatesec -ge $startdatesec ];
    then
        echo "[`date`] # CLIPPING $JEB_JULIA_VERSION TO DATE THRESHOLD "
	export JEB_REGISTRY_START_DATE=$JEB_THRESHOLD_DATE
    fi

    echo "[`date`] # RUNNING "
    echo $JEB_JULIA_VERSION
    echo $JEB_REGISTRY_START_DATE
    echo $JEB_REGISTRY_END_DATE
    echo "====="
    ./run_all_between_dates.sh
done

