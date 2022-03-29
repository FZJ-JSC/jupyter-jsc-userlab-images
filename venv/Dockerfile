FROM ubuntu:focal-20220316

ENV DEBIAN_FRONTEND noninteractive

ENV USERNAME=jovyan

# create the app user
RUN adduser --uid 1000 --ingroup users --gecos "" --disabled-password ${USERNAME}

RUN apt update && \
    apt -y upgrade && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

COPY requirements_apt.txt /tmp/requirements_apt.txt
COPY requirements_pip.txt /tmp/requirements_pip.txt

RUN apt update && \
    cat /tmp/requirements_apt.txt | xargs apt install -yq && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip install -r /tmp/requirements_pip.txt && \
    chown -R ${USERNAME}:users ${HOME} && \
    rm /tmp/requirements_pip.txt && \
    rm /tmp/requirements_apt.txt

USER jovyan
