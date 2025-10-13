#!/usr/bin/env sh

if [ -n "$GITHUB_TOKEN" ]
then
    echo "overwriting git remote to use GITHUB_TOKEN"
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/JuliaEcosystemBenchmarks/julia-ecosystem-benchmarks.git/"
fi

julia +release --project=. -tauto,auto -e "using Pkg; Pkg.instantiate(); Pkg.update()"
julia +release --project=. -tauto,auto ttfx_snippets_gather_data.jl
julia +release --project=. -tauto,auto ttfx_snippets_vis.jl

git stash push --include-untracked -- *.csv
git stash push --include-untracked -- plots/Julia-TTFX-Snippets/*
git fetch
git pull
git checkout jeb_logs
git pull
rm -r plots/Julia-TTFX-Snippets/*
rm -r data/Julia-TTFX-Snippets/*
mkdir -p plots/Julia-TTFX-Snippets
mkdir -p data/Julia-TTFX-Snippets
git stash pop
git stash pop
mv ttfx_snippets_data.csv data/Julia-TTFX-Snippets/
git add plots
git add data
git commit -m "daily plots and data $CURRENT_V $CURRENT_DATE"
git push
git checkout master
