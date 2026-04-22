#!/bin/sh
set -e

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
SVER="20240101"         #-- When updated
#VERBOSE=1              #-- 1 - be verbose flag, defined outside of the script

MDB_CONF="/etc/my.cnf"
DIR_CONF="/etc/my.cnf.d"
DIR_RUN="/run/mysqld"
DIR_DB="/var/lib/mysql"
DIR_INITDB="/docker-entrypoint-initdb.d"

#-- Externally defined variables
#USER=mysql
#PUID=1000
#PGID=1000
#TZ America/Toronto
#MYSQL_ROOT_PASSWORD
#MYSQL_DATABASE
#MYSQL_USER
#MYSQL_PASSWORD
#MYSQL_CHARSET
#MYSQL_COLLATION
#MYSQL_REPLICATION_USER
#MYSQL_REPLICATION_PASSWORD
#MYSQL_REPLICA_FIRST
#VERBOSE=0

source /functions.sh  #-- Use common funcations


#=============================================================================
#
#  MAIN()
#
#=============================================================================
dlog '============================================================================='
dlog "[ok] - starting entrypoint.sh ver $SVER"

#-- get additional information
get_container_details
ip addr show eth0
dlog "User details (uid,gid):"
id $USER

#-----------------------------------------------------------------------------
# Adjust parameters
#-----------------------------------------------------------------------------

#-- Modify Group ID if needed
CGID=$(id -g $USER)
if [ $PGID -ne $CGID ] ; then
    groupmod --gid $PGID $USER
	is_good "[ok] - changed gid from $CGID to $PGID for $USER" \
	"[not ok] - changing gid from $CGID to $PGID for $USER" 
fi

#-- Modify User and Group ID if needed
CUID=$(id -u $USER)
if [ $PUID -ne $CUID ] ; then
    usermod --gid $PGID --uid $PUID $USER
	is_good "[ok] - changed uid from $CUID to $PUID for $USER" \
	"[not ok] - changing gid from $CUID to $PUID for $USER" 
fi

#-- Modify TimeZone  if needed
if [ "$TZ" != "$(cat /etc/timezone)" ] ; then
    cp /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo "$TZ" >  /etc/timezone;
fi

#-----------------------------------------------------------------------------
# Work with MariaDB
#-----------------------------------------------------------------------------
if [ ! -d $DIR_RUN ]; then
    dlog "[ok] -  mysqld not found, creating...."
    mkdir -p $DIR_RUN
else
    dlog "[ok] - mysqld exists, skipping creation"
fi
chown -R $USER:$USER $DIR_RUN


#-- Verify if configuration directory exists
if [ ! -d $DIR_CONF ]; then
    dlog "[ok] -  directory $DIR_CONF not found, creating...."
    mkdir -p $DIR_CONF
else
    dlog "[ok] - directory $DIR_CONF exists, skipping creation"
fi
chown -R $USER:$USER $DIR_CONF

#-- Verify if configuration file exists
if [ ! -s $MDB_CONF ] ; then
    dlog "[ok] -  configuration file $MDB_CONF not found, creating...."
    #-- Create a simple config file
    cat << EOC > $MDB_CONF
[client-server]

# include *.cnf from the config directory
!includedir /etc/my.cnf.d
EOC
else 
    dlog "[ok] - configuration file $MDB_CONF exists, skipping creation"
fi

#-- Create new Database, if needed
if [ ! -d $DIR_DB/mysql ]; then
    #-- Copied from: https://github.com/yobasystems/alpine-mariadb/blob/master/alpine-mariadb-amd64/files/run.sh
    dlog "[ok] - MySQL data directory not found, creating initial DBs"

    chown -R $USER:$USER $DIR_DB

    mysql_install_db --user=$USER --ldata=$DIR_DB > /dev/null

    if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
        MYSQL_ROOT_PASSWORD=`pwgen 16 1`
        echo "[ok] - MySQL root Password: $MYSQL_ROOT_PASSWORD"
    fi

    MYSQL_DATABASE=${MYSQL_DATABASE:-""}
    MYSQL_USER=${MYSQL_USER:-""}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

    tfile=`mktemp`
    if [ ! -f "$tfile" ]; then
        return 1
    fi

    cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES ;
GRANT ALL ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
DROP DATABASE IF EXISTS test ;
FLUSH PRIVILEGES ;
EOF

    if [ "$MYSQL_DATABASE" != "" ]; then
        dlog "[ok] - Creating database: $MYSQL_DATABASE"
        if [ "$MYSQL_CHARSET" != "" ] && [ "$MYSQL_COLLATION" != "" ]; then
            dlog "[ok] - with character set [$MYSQL_CHARSET] and collation [$MYSQL_COLLATION]"
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> $tfile
        else
            dlog "[ok] - with character set: 'utf8' and collation: 'utf8_general_ci'"
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile
        fi

        if [ "$MYSQL_USER" != "" ]; then
            dlog "[ok] - Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
            echo "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
            echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';" >> $tfile
        fi
    fi

    echo "FLUSH PRIVILEGES;" >> $tfile

    /usr/bin/mysqld --user=$USER --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < $tfile
    rm -f $tfile

    dlog '[ok] - MySQL init process done. Ready for start up.'

    #-------------------------------------------------------------------------
    # Process /docker-entrypoint-initdb.d scripts (first boot only)
    #-------------------------------------------------------------------------
    if [ -d "$DIR_INITDB" ] && [ "$(ls -A $DIR_INITDB 2>/dev/null)" ]; then
        dlog "[ok] - Found files in $DIR_INITDB, running init scripts..."

        #-- Start a temporary server in background (local socket only, no networking)
        #-- Note: --daemonize is not available in Alpine builds of MariaDB
        /usr/bin/mysqld \
            --user=$USER \
            --skip-name-resolve \
            --skip-networking \
            --socket=/run/mysqld/mysqld_init.sock \
            --pid-file=/run/mysqld/mysqld_init.pid &
        MYSQLD_INIT_PID=$!

        #-- Wait until the temporary server accepts connections
        RETRIES=30
        while [ $RETRIES -gt 0 ]; do
            if mysqladmin \
                --socket=/run/mysqld/mysqld_init.sock \
                --user=root \
                --password="$MYSQL_ROOT_PASSWORD" \
                ping --silent 2>/dev/null; then
                break
            fi
            dlog "[ok] - Waiting for temporary mysqld to be ready... ($RETRIES retries left)"
            sleep 1
            RETRIES=$((RETRIES - 1))
        done

        if [ $RETRIES -eq 0 ]; then
            dlog "[not ok] - Temporary mysqld did not start in time, aborting init scripts."
            exit 1
        fi

        dlog "[ok] - Temporary mysqld is ready. Processing init scripts..."

        #-- Helper: run SQL against the temporary server
        run_sql() {
            mysql \
                --socket=/run/mysqld/mysqld_init.sock \
                --user=root \
                --password="$MYSQL_ROOT_PASSWORD" \
                ${MYSQL_DATABASE:+--database="$MYSQL_DATABASE"} \
                "$@"
        }

        #-- Iterate files in sorted order (same behaviour as official image)
        for f in $(ls "$DIR_INITDB" | sort); do
            fpath="$DIR_INITDB/$f"
            case "$f" in
                *.sh)
                    dlog "[ok] - Running shell script: $f"
                    # Execute with access to env vars; scripts may call mysql themselves
                    sh "$fpath"
                    ;;
                *.sql)
                    dlog "[ok] - Importing SQL file: $f"
                    run_sql < "$fpath"
                    ;;
                *.sql.gz)
                    dlog "[ok] - Importing compressed SQL file: $f"
                    gunzip -c "$fpath" | run_sql
                    ;;
                *)
                    dlog "[ok] - Ignoring unknown file type: $f"
                    ;;
            esac
        done

        #-- Shutdown the temporary server gracefully via SIGTERM
        dlog "[ok] - Shutting down temporary mysqld (PID $MYSQLD_INIT_PID)..."
        kill -TERM $MYSQLD_INIT_PID

        #-- Wait for the process to fully exit
        wait $MYSQLD_INIT_PID 2>/dev/null || true

        #-- Extra safety: wait for socket to disappear
        RETRIES=30
        while [ $RETRIES -gt 0 ] && [ -S /run/mysqld/mysqld_init.sock ]; do
            sleep 1
            RETRIES=$((RETRIES - 1))
        done

        dlog "[ok] - Init scripts from $DIR_INITDB completed."
    else
        dlog "[ok] - No init scripts found in $DIR_INITDB, skipping."
    fi
    #-- end initdb.d -----------------------------------------------------------

else
    chown -R $USER:$USER $DIR_DB
    dlog "[ok] - MySQL directory exists, skipping creation"
fi

#-- Check if First Cluster node requires
if [ $MYSQL_REPLICA_FIRST -gt 0 ] ; then
    WSREP="--wsrep-new-cluster"
    dlog "[ok] - first node in the cluster"
else 
    WSREP=""
fi
#--skip-networking=0
exec /usr/bin/mysqld --user=$USER --console ${WSREP} --skip-name-resolve $@
