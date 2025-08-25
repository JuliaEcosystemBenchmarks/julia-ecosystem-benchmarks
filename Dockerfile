FROM debian:12

RUN mkdir /workdir
WORKDIR /workdir

RUN apt update && apt install -y git wget curl build-essential htop time bc && apt clean

RUN curl -fsSL https://install.julialang.org | sh -s -- --yes

RUN git config --global user.email "jebdockerbot@krastanov.org"
RUN git config --global user.name "JEB Bot"
