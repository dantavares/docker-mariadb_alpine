#!/bin/bash
#--------------------------------------------------------------------------------------------------
# Sample scipt to start new MariaBD as a container with volumes, 
#  but they cou be without content to generate default
#
# WARNING:
# Password has to be created in advance 
#   or the entrypoint script will create a random one (see in `docker logs $IMG`)
#--------------------------------------------------------------------------------------------------

IMG_NAME=mariadb
ROOT_PWD="It-Shoul291Be+str0ng"    #-- Sample root password for MariaDB. !!Change it!!
IP2RUN=""                #-- set specific IP, sample: "10.1.1.35:" <- notice ':' at the end
VERBOSE=1                #-- 1 - be verbose flag
SVER="20211103"

#-- Check architecture
[[ $(uname -m) =~ ^armv7 ]] && ARCH="armv7-" || ARCH=""

source ./functions.sh #-- Use common functions

stop_container   $IMG_NAME
remove_container $IMG_NAME

docker run -d \
  --name $IMG_NAME \
  -p ${IP2RUN}3306:3306  \
  -v /your_config_dir:/etc/my.cnf.d \
  -v /your_data_dir:/var/lib/mysql \
  -e VERBOSE=${VERBOSE} \
  -e MYSQL_ROOT_PASSWORD=${ROOT_PWD} \
  etaylashev/mariadb:${ARCH}latest
exit 0

