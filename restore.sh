#!/bin/bash
#-----------------------------------------------------------------------
# Sample script to restore a MariaDB from a file to the running container
# 
# Usage: $0 backup_file
#
#
# Password to access the DB could be provided multiple ways:
#   1) Hardcoded in the script as a text
#   2) Defined externally: i.e. export ROOT_PWD=some_passwd
#   3) Obtained from a file: ROOT_PWD=$(read_secret ./root_password.txt)
#
#-----------------------------------------------------------------------
#set -e

#-- Main settings
SVER="20211103"
IMG_NAME=mariadb      #-- container/image name
DB="--all-databases"  #-- to backup specific DB or ALL 

DIR_BACKUP="."        #-- directory for backups
FILE_BACKUP=""        #-- file with SQL commands, could be .sql or bz2

ROOT_PWD="xa-xa22"    #-- Sample root password for MariaDB. !!Change it!!
#-- Password could be obtained from a file using function
#ROOT_PWD=$(read_secret ./root_password.txt)

VERBOSE=1             #-- 1 - be verbose flag

source ./functions.sh #-- Use common functions

#-------------------------------------------------------------------------------
dlog "[ok] - started restore script ver $SVER on $(date)"

#-- Test that the container is running
if is_run_container ${IMG_NAME}; then
    dlog "[ok] - Container ${IMG_NAME} is running"
else
    derr "[not ok] - Container ${IMG_NAME} is NOT running"
    derr 'Aborting restore...'
    exit 1
fi

#-- Check input args
if [ $# -ge 1 ] ;  then
    FILE_BACKUP=$1
    dlog "[ok] - SQL archive: $FILE_BACKUP"
else
    derr "[not ok] - need a backup archive with SQL commands"
    echo "Usage: $0 sql_backup"
fi

#-- Check that file exists
if [ ! -s ${FILE_BACKUP} ] ; then
    derr "[not ok] - backup archive ${FILE_BACKUP} does not exist. Exiting..."
    exit 2
fi

#-- Check do we need to unpack
if [[ ${FILE_BACKUP} =~ bz2$ ]] ; then
    dlog "[ok] - unpacking with bzip2"
    bzip2 --decompress ${FILE_BACKUP}

    #-- remove bz2 extension
    FILE_BACKUP=$(echo ${FILE_BACKUP} | sed -e 's/\.bz2$//')
    dlog "[ok] - file to use ${FILE_BACKUP}"
fi


#-- Peform restore
docker exec ${IMG_NAME} /bin/sh -c "/usr/bin/mariadb -uroot -p\"${ROOT_PWD}\"" <${FILE_BACKUP}
is_good "[ok] - restored SQL content" \
"[not ok] - restoring SQL content"

#-- We done
dlog "[ok] - We done."
exit 0
