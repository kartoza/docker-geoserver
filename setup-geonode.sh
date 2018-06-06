#!/usr/bin/env bash

apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y python python-pip python-dev \
    && chmod +x /usr/local/tomcat/tmp/*.sh \
    && pip install --upgrade pip && hash -r \
    && pip install -r requirements.txt \
    && chmod +x /usr/local/tomcat/tmp/*.py


