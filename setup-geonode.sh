#!/usr/bin/env bash

apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y python python-pip python-dev python-setuptools \
    && chmod +x /usr/local/tomcat/tmp/*.sh \
    && python -m pip install --upgrade pip \
    && pip install -r requirements.txt \
    && chmod +x /usr/local/tomcat/tmp/*.py

