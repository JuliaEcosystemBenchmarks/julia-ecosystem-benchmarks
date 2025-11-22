#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 

echo "[`date`] ##############################"
echo "[`date`] # REGISTRY SETUP"
echo "[`date`] ##############################"
cd timetravel_registry
echo "[`date`] # CLONE OR CHECKOUT"
if [ ! -d General/.git ]
then
    echo "[`date`] # NO REPO; PROCEED WITH CLONE"
    git clone https://github.com/JuliaRegistries/General
else
    echo "[`date`] # REPO EXISTS; PROCEED WITH PRUING/GC ..."
    rm -r General/.git/refs/remotes/origin
    git -C General fetch -p
    git -C General remote prune origin
    git -C General gc --aggressive --prune=now
    echo "[`date`] # ... AND FORCED CHECKOUT ..."
    git -C General checkout --force master
    echo "[`date`] # ... AND FORCED PULL"
    git -C General pull --force
fi
cd General
echo "[`date`] # CHECKOUT DATE=$JEB_REGISTRY_DATE"
git checkout `git rev-list master -n 1 --first-parent --before="$JEB_REGISTRY_DATE"`
git log -n1
cd ../..

rm -rf $JULIA_DEPOT_PATH/registries

juliaup add $JEB_JULIA_VERSION

julia +$JEB_JULIA_VERSION -e 'using Pkg; Pkg.Registry.add(RegistrySpec(url="timetravel_registry/General"))'

