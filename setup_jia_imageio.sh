#!/usr/bin/env bash

cd $JAVA_HOME && \
wget http://data.opengeo.org/suite/jai/jai-1_1_3-lib-linux-amd64-jdk.bin && \
echo "yes" | sh jai-1_1_3-lib-linux-amd64-jdk.bin && \
rm jai-1_1_3-lib-linux-amd64-jdk.bin

cd $JAVA_HOME && \
export _POSIX2_VERSION=199209 &&\
wget http://data.opengeo.org/suite/jai/jai_imageio-1_1-lib-linux-amd64-jdk.bin && \
echo "yes" | sh jai_imageio-1_1-lib-linux-amd64-jdk.bin && \
rm jai_imageio-1_1-lib-linux-amd64-jdk.bin