#!/usr/bin/env sh

if [ -n "$GITHUB_TOKEN" ]
then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/JuliaEcosystemBenchmarks/julia-ecosystem-benchmarks.git/"
fi

git add logs
git stash push --staged
git fetch
git pull
git checkout jeb_logs
git pull
git stash pop
git add logs
git commit -m "daily logs $CURRENT_V $CURRENT_DATE"
git push
git checkout master
