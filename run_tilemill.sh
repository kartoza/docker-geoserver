#!/bin/bash


# Set the locale - see http://jaredmarkell.com/docker-and-locales/
# a work around for this error when running tilemill:
# what():  locale::facet::_S_create_c_locale name not valid
locale-gen en_US.UTF-8  
export LANG en_US.UTF-8  
export LANGUAGE en_US:en  
export LC_ALL en_US.UTF-8 
TILEMILL_HOST=`ifconfig eth0 | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1}'` 
cd /usr/share/tilemill
./index.js --server=true --listenHost=0.0.0.0 --coreUrl=${TILEMILL_HOST}:20009 --tileUrl=${TILEMILL_HOST}:20008
