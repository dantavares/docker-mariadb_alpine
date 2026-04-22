#!/bin/bash
#-----------------------------------------------------------------------------
# Sample script to backup a DB in MariaDB or all databases
#
# Alternatevely backup files from the mounted data volume
#
# Password to access the DB could be provided multiple ways:
#   1) Hardcoded in the script as a text
#   2) Defined externally: i.e. export ROOT_PWD=some_passwd
#   3) Obtained from a file: ROOT_PWD=$(read_secret ./root_password.txt)
#
#-----------------------------------------------------------------------------

source ./functions.sh #-- Use common functions

#-- Main settings
IMG_NAME=mariadb      #-- container/image name
DB="--all-databases"  #-- to backup specific DB or ALL 

DIR_BACKUP="."        #-- directory for backups
FILE_BACKUP=${DIR_BACKUP}/mariadb-$(date "+%Y%m%d")

ROOT_PWD="xa-xa22"    #-- Sample root password for MariaDB. !!Change it!!
#-- Password could be obtained from a file using function
#ROOT_PWD=$(read_secret ./root_password.txt)

VERBOSE=1                #-- 1 - be verbose flag
SVER="20211103"

#-------------------------------------------------------------------------------
dlog "[ok] - started backup script ver $SVER on $(date)"

#-- Test that the container is running
if is_run_container ${IMG_NAME}; then
    dlog "[ok] - Container ${IMG_NAME} is running"
else
    derr "[not ok] - Container ${IMG_NAME} is NOT running"
    derr 'Aborting backup...'
    exit 13
fi

#-- Peform backup
docker exec ${IMG_NAME} /bin/sh -c "/usr/bin/mysqldump --opt -uroot -p\"${ROOT_PWD}\" ${DB}" >${FILE_BACKUP}.sql

#-- Compress it
if [ -s ${FILE_BACKUP}.sql ] && command -v bzip2 &> /dev/null ; then

  #-- Compress the SQL file
  bzip2 --compress --best ${FILE_BACKUP}.sql
  is_good "[ok] - compressed the SQL backup file" \
  "[not ok] - compressing the SQL backup file"
  FILE_BACKUP="${FILE_BACKUP}.sql.bz2"
fi

#-- We done
dlog "[ok] - We done. Backup file is ${FILE_BACKUP}"
exit 0
