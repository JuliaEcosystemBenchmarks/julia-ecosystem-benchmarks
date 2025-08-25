#!/usr/bin/env sh

julia +release --project=. -tauto,auto -e "using Pkg; Pkg.instantiate(); Pkg.update()"
julia +release --project=. -tauto,auto ttfx_snippets_gather_data.jl
julia +release --project=. -tauto,auto ttfx_snippets_vis.jl

if [ -n "$GITHUB_TOKEN" ]
then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/JuliaEcosystemBenchmarks/julia-ecosystem-benchmarks.git/"
fi

git stash push --include-untracked -- plots/Julia-TTFX-Snippets/*
git fetch
git pull
git checkout jeb_logs
git pull
rm -r plots/Julia-TTFX-Snippets/*
git stash pop
git add plots
git commit -m "daily plots $CURRENT_V $CURRENT_DATE"
git push
git checkout master
