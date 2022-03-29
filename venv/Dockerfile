FROM jupyter/base-notebook:hub-2.1.1
USER root
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y curl wget
USER jovyan
