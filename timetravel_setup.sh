#!/usr/bin/env sh

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_CI=true
export JULIA_DEPOT_PATH=$PWD/depot 

cd timetravel_registry
git clone https://github.com/JuliaRegistries/General || (git -C General checkout --force master; git -C General pull --force)
cd General
git checkout `git rev-list master -n 1 --first-parent --before="$JEB_REGISTRY_DATE"`
git log -n1
cd ../..

rm -rf $JULIA_DEPOT_PATH/registries

juliaup add $JEB_JULIA_VERSION

julia +$JEB_JULIA_VERSION -e 'using Pkg; Pkg.Registry.add(RegistrySpec(url="timetravel_registry/General"))'

