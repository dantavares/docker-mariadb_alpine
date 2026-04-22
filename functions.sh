#=============================================================================
#
#  Common Functions for managing docker containers 
#
#
#=============================================================================
FVER="20211102"     #-- version of functions

#-----------------------------------------------------------------------------
#  Output debugging/logging message
#------------------------------------------------------------------------------
dlog(){
  local TSMP=$(date -Iseconds)
  local MSG="$TSMP $1"

  #-- var $VERBOSE is defined in a script
  [ "$VERBOSE" == "1" ] && echo "$MSG"

  #-- log to a file if var $FLOG defined in a script
  if [ "$FLOG" != "" ] ; then
    echo "$MSG" >>$FLOG
  fi
}
# function dlog


#-----------------------------------------------------------------------------
#  Output error message
#------------------------------------------------------------------------------
derr(){
  local TSMP=$(date -Iseconds)
  local MSG="$TSMP $1"

  echo "$MSG"

  #-- log to a file if var $FLOG defined in a script
  if [ "$FLOG" != "" ] ; then
    echo "$MSG" >>$FLOG
  fi
}
# function derr


#-----------------------------------------------------------------------------
#  Output good or bad message based on return status $?
#------------------------------------------------------------------------------
is_good(){
    local STATUS=$?
    local MSG_GOOD="$1"
    local MSG_BAD="$2"
    
    if [ $STATUS -eq 0 ] ; then
        dlog "${MSG_GOOD}"
    else
        derr "${MSG_BAD}"
    fi
}
# function is_good


#-----------------------------------------------------------------------------
#  Output good or bad message based on return status $? and exit on failure
#------------------------------------------------------------------------------
is_critical(){
    local STATUS=$?
    local MSG_GOOD="$1"
    local MSG_BAD="$2"
    
    if [ $STATUS -eq 0 ] ; then
        dlog "${MSG_GOOD}"
    else
        derr "${MSG_BAD}"
        exit 1
    fi
}
# function is_critical


#-----------------------------------------------------------------------------
# Returns content of the input file, skipping lines with #
#-----------------------------------------------------------------------------
read_secret(){ 
    local secret=$(cat "$1" | sed -e '/^#/d'); 
    echo "$secret"; 
}
# function read_secret


#-----------------------------------------------------------------------------
# Check if the container is running by the name
# Input: container name
#-----------------------------------------------------------------------------
is_run_container(){
  local IMG_N="$1"
  local IMG_ID=$(docker ps -qf "name=^$IMG_N$")
  if [ "x$IMG_ID" != "x" ] ; then
        # 0 = true
        return 0
    else
        # 1 = false
        return 1
  fi
}
# function is_run_container


#-----------------------------------------------------------------------------
# Stop the container by the name if running
# Input: container name
#-----------------------------------------------------------------------------
stop_container(){
  local IMG_N="$1"
  local IMG_ID=$(docker ps -qf "name=^$IMG_N$")
  if [ "x$IMG_ID" != "x" ] ; then
    dlog "[ok] - stopping $IMG_N ($IMG_ID)"
    docker stop $IMG_ID
	is_good "[ok] - stopped $IMG_N" \
	"[not ok] - ERROR stopping $IMG_N"
  fi
}
# function stop_container


#-----------------------------------------------------------------------------
# Remove the container by the name if exists
# Input: container name
#-----------------------------------------------------------------------------
remove_container(){
  local IMG_N="$1"
  local IMG_ID=$(docker ps -qaf "name=^$IMG_N$")
  if [ "x$IMG_ID" != "x" ] ; then
    dlog "[ok] - removing $IMG_N ($IMG_ID)"
    docker rm $IMG_ID
	is_good "[ok] - removed $IMG_N" \
	"[not ok] - ERROR removing $IMG_N"
  fi
}
# function remove_container

#-----------------------------------------------------------------------------
#  Output important parametrs of the container
#------------------------------------------------------------------------------
get_container_details(){

    if [ $VERBOSE -eq 1 ] ; then
        echo '[ok] - getting container details:'
        echo '---------------------------------------------------------------------'

        #-- for Linux Alpine
        if [ -f /etc/alpine-release ] ; then
            OS_REL=$(cat /etc/alpine-release)
            echo "Alpine $OS_REL"
            apk -v info | sort
        fi
	if ! command -v uname &> /dev/null ; then
            uname -a
        fi
	if ! command -v ip &> /dev/null ; then
            ip addr
        fi
        echo '---------------------------------------------------------------------'
    fi
}
# function get_container_details
