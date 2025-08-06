FROM debian:12

RUN mkdir /workdir
WORKDIR /workdir

RUN apt update && apt install -y git wget curl build-essential htop time && apt clean

RUN curl -fsSL https://install.julialang.org | sh -s -- --yes
