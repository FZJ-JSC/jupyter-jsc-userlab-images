FROM jupyter/base-notebook:hub-2.1.1
USER root
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt remove -y curl libcurl4 librtmp1 && apt autoremove -y && apt install -y curl
