#!/usr/bin/env bash
#=============================================================================
# Perform functionality tests for the docker-mariadb image
#
#  Steps:
#  - start the container/image
#  - get list of default databases
#  - create a database and a table
#  - insert values into the table
#  - query a value
#  - stop the container
#=============================================================================

#------------------------------------------------------------------------------------
#
#  Variable declarations
#
#------------------------------------------------------------------------------------
SVER="20211103"     #-- Updated date
VERBOSE=1          #-- 1 - be verbose flag

IMG_NAME=test-db               #-- container/image name
ROOT_PWD="It-Shoul291Be+str0ng"    #-- Sample root password for MariaDB. !!Change it!!
SQL_PRE="docker exec ${IMG_NAME} /bin/sh -c '/usr/bin/mariadb -uroot -p\"$MYSQL_ROOT_PASSWORD\" "

#-- Check architecture
[[ $(uname -m) =~ ^armv7 ]] && ARCH="armv7-" || ARCH=""

n=0  #-- count number of tests
g=0  #-- count success
b=0  #-- count failure

#=============================================================================
#
#  MAIN()
#
#=============================================================================

source ./functions.sh        #-- Use common functions

dlog "[ok] - started docker-mariadb testing script ver $SVER on $(date)"

#-- start the container/image
stop_container   $IMG_NAME
remove_container $IMG_NAME

docker run -d \
  --name $IMG_NAME \
  -p 3306:3306  \
  -e VERBOSE=1 \
  -e MYSQL_ROOT_PASSWORD=${ROOT_PWD} \
  etaylashev/mariadb:${ARCH}latest
is_critical "[ok] - started image ${IMG_NAME}" \
"[not ok] - started image ${IMG_NAME}"

#-- some delay to get it running
dlog 'sleeping 10 sec for full init ...'
sleep 10

#== Test 1: get list of default databases
n=$((n+1))
CMD="${SQL_PRE} -e \"show databases;\"'"
#echo $CMD

#docker exec test-db /bin/sh -c "/usr/bin/mariadb -uroot -p\"$ROOT_PWD\" -e 'show databases;'"
RES_ALL=$(eval $CMD)

RES_SQL="information_schema"      #-- expected result

if [[ "$RES_ALL" =~ "$RES_DNS" ]] ; then
    dlog "[ok] - ($n) MariaDB is responding"
    g=$((g+1))
else
    dlog "[not ok] - ($n) MariaDB is NOT responding"
    b=$((b+1))
    echo "Aborting...."
    exit 13
fi


#== Test 2: create a database and a table
n=$((n+1))
SQL="create database if not exists test_db;"
SQL+="use test_db;"
SQL+="create table if not exists t_table (param INTEGER,val varchar(50));"

CMD="${SQL_PRE} -e \"${SQL}\"'"
#echo $CMD

eval $CMD
if [ $? -eq 0 ] ; then
    dlog "[ok] - ($n) created a database and a table"
    g=$((g+1))
else
    dlog "[not ok] - ($n) can't create a database and a table"
    b=$((b+1))
fi


#== Test 3: insert values into the table
n=$((n+1))
SQL="use test_db;"
SQL+="insert into t_table values (1,\\\"param_1\\\"),(2,\\\"param_2\\\");"

CMD="${SQL_PRE} -e \"${SQL}\"'"
#echo $CMD

eval $CMD
if [ $? -eq 0 ] ; then
    dlog "[ok] - ($n) inserted values into the table"
    g=$((g+1))
else
    dlog "[not ok] - ($n) can't insert values into the table"
    b=$((b+1))
fi


#== Test 4: query the value
n=$((n+1))
SQL="use test_db;"
SQL+="select val from t_table where param=2;"

CMD="${SQL_PRE} -e \"${SQL}\"'"
#echo $CMD

RES_ALL=$(eval $CMD)

RES_SQL='param_2'      #-- expected result
if grep -q "$RES_ALL" <<< $RES_SQL ; then
    dlog "[ok] - ($n) queried the value from the table"
    g=$((g+1))
else
    dlog "[not ok] - ($n) can't query the value from the table"
    b=$((b+1))
fi


#== Test 5: delete the test database
n=$((n+1))
SQL="drop database if exists test_db;"

CMD="${SQL_PRE} -e \"${SQL}\"'"
#echo $CMD

eval $CMD
if [ $? -eq 0 ] ; then
    dlog "[ok] - ($n) delete the test database"
    g=$((g+1))
else
    dlog "[not ok] - ($n) can't delete the test database"
    b=$((b+1))
fi


#-- stop the container
stop_container   $IMG_NAME
remove_container $IMG_NAME

#-- Done!
dlog "[ok] - We are done: $g - success; $b - failure; $n total tests"
exit 0

