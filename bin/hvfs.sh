#!/bin/bash
##
# Copyright (c) 2009 Ma Can <ml.macana@gmail.com>
#                           <macan@ncic.ac.cn>
#
# Time-stamp: <2012-09-03 13:10:39 macan>
#
# This is the mangement script for Pomegranate
#
# Armed with EMACS.

SYSCTL_ADJ_SYN="sysctl -w net.ipv4.tcp_max_syn_backlog=8192;"

if [ "x$HVFS_HOME" == "x" ]; then
    HVFS_HOME=`pwd`
    TAIL=`basename $HVFS_HOME`
    if [ "x$TAIL" == 'xbin' ]; then
        HVFS_HOME=`dirname $HVFS_HOME`
    fi
fi

if [ "x$CFILE" == "x" ]; then
    CONFIG_FILE="$HVFS_HOME/conf/hvfs.conf"
else
    CONFIG_FILE="$HVFS_HOME/conf/$CFILE"
fi

if [ "x$LOG_DIR" == "x" ]; then
    LOG_DIR="~"
fi
export LOG_DIR

if [ "x$PASSWD" == "x" ]; then
    # it is the normal mode, we do not use expect
    SSH="ssh -x"
else
    # we have to use expect to login
    SSH="$HVFS_HOME/bin/rexec.exp $PASSWD"
    if [ ! -x /usr/bin/expect ]; then
        echo "/usr/bin/expect does not exist. Use 'which expect' to find it and update the header in file 'rexec.exp'."
    fi
fi

if [ "x$USERNAME" == "x" ]; then
    UN=""
else
    UN="$USERNAME@"
fi

function do_conf_check() {
    if [ -d $HVFS_HOME/conf ]; then
        if [ -e $CONFIG_FILE ]; then
        # It is ok to continue
            return
        else
            echo "Missing config files."
            echo "Please check your home path, and make sure the config file"
            echo "'hvfs.conf' is in HVFS_HOME/conf/."
            exit
        fi
    else
        echo "Corrupt home path: $HVFS_HOME."
        echo "Please check your home path, and make sure the config file"
        echo "'hvfs.conf' is in HVFS_HOME/conf/."
        exit
    fi
}

# check if the config file exists.
do_conf_check

function do_ut_conf_check() {
    if [ -e $HVFS_HOME/conf/ut.conf ]; then
        return
    else
        echo "Missing config file: ut.config."
        echo "Please check your home path, and make sure the config file"
        echo "'ut.conf' is in HVFS_HOME/conf/."
        exit
    fi
}

# Read the config file and start the servers 

ROOT_CMD="LOG_DIR=$LOG_DIR create=0 mode=1 hvfs_root_hb_interval=10"

#Construct the mdsl command line
if [ -e $HVFS_HOME/conf/mdsl.conf ]; then
    # Using the config file
    if [ "x$MODE" == "xfs" ]; then
        ARGS=`cat $HVFS_HOME/conf/mdsl.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        MDSL_CMD="LOG_DIR=$LOG_DIR fsid=0 "`echo $ARGS`
    elif [ "x$MODE" == "xkv" ]; then
        ARGS=`cat $HVFS_HOME/conf/mdsl.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        MDSL_CMD="LOG_DIR=$LOG_DIR fsid=1 "`echo $ARGS`
    else
        ARGS=`cat $HVFS_HOME/conf/mdsl.conf | grep -v "^ *#" | grep -v "^$"`
        MDSL_CMD="LOG_DIR=$LOG_DIR "`echo $ARGS`
    fi
else
    if [ "x$MODE" == "xfs" ]; then
        MDSL_CMD="fsid=0 mode=1 hvfs_mdsl_prof_plot=1 hvfs_mdsl_opt_write_drop=0"
    else
        MDSL_CMD="fsid=1 mode=1 hvfs_mdsl_prof_plot=1 hvfs_mdsl_opt_write_drop=0"
    fi
fi

# Construct the mds command line
if [ -e $HVFS_HOME/conf/mds.conf ]; then
    # Using the config file
    if [ "x$MODE" == "xfs" ]; then
        ARGS=`cat $HVFS_HOME/conf/mds.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        MDS_CMD="LOG_DIR=$LOG_DIR fsid=0 "`echo $ARGS`
    elif [ "x$MODE" == "xkv" ]; then
        ARGS=`cat $HVFS_HOME/conf/mds.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        MDS_CMD="LOG_DIR=$LOG_DIR fsid=1 "`echo $ARGS`
    else
        ARGS=`cat $HVFS_HOME/conf/mds.conf | grep -v "^ *#" | grep -v "^$"`
        MDS_CMD="LOG_DIR=$LOG_DIR "`echo $ARGS`
    fi
else
    if [ "x$MODE" == "xfs" ]; then
        MDS_CMD="fsid=0 mode=1 hvfs_mds_opt_memlimit=0 hvfs_mds_memlimit=1072896010 hvfs_mds_txg_interval=5 hvfs_mds_opt_memonly=0 type=0 cache=0"
    else
        MDS_CMD="fsid=1 mode=1 hvfs_mds_opt_memlimit=0 hvfs_mds_memlimit=1072896010 hvfs_mds_txg_interval=5 hvfs_mds_opt_memonly=0 type=0 cache=0"
    fi
fi

# Construct the osd command line
if [ -e $HVFS_HOME/conf/osd.conf ]; then
    # Using the config file
    if [ "x$MODE" == "xfs" ]; then
        ARGS=`cat $HVFS_HOME/conf/osd.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        OSD_CMD="LOG_DIR=$LOG_DIR fsid=0 "`echo $ARGS`
    elif [ "x$MODE" == "xkv" ]; then
        ARGS=`cat $HVFS_HOME/conf/osd.conf | grep -v "^ *#" | grep -v "^$" | grep -v "fsid="`
        OSD_CMD="LOG_DIR=$LOG_DIR fsid=1 "`echo $ARGS`
    else
        ARGS=`cat $HVFS_HOME/conf/osd.conf | grep -v "^ *#" | grep -v "^$"`
        OSD_CMD="LOG_DIR=$LOG_DIR "`echo $ARGS`
    fi
else
    if [ "x$MODE" == "xfs" ]; then
        OSD_CMD="fsid=0 mode=1 hvfs_osd_prof_plot=1 hvfs_osd_opt_write_drop=0"
    else
        OSD_CMD="fsid=1 mode=1 hvfs_osd_prof_plot=1 hvfs_osd_opt_write_drop=0"
    fi
fi

CLIENT_CMD=""

ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4}'`
R2IP=`echo $ipnr | awk -F: '{print $1}'`

function adjust_syn() {
    ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4":"$3}'`
    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        $SSH $UN$ip "$SYSCTL_ADJ_SYN" > /dev/null &
    done
    echo "Adjust SYN on r2 server done."
    ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4":"$3}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        $SSH $UN$ip "$SYSCTL_ADJ_SYN" > /dev/null &
    done
    echo "Adjust SYN on MDSL server done."
    ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4":"$3}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        $SSH $UN$ip "$SYSCTL_ADJ_SYN" > /dev/null &
    done
    echo "Adjust SYN on OSD server done."
    ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4":"$3}'`
    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        $SSH $UN$ip "$SYSCTL_ADJ_SYN" > /dev/null &
    done
    echo "Adjust SYN on MDS server done."
}

function start_mdsl() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do 
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$MDSL_CMD $HVFS_HOME/test/xnet/mdsl.ut $id $R2IP $port > $LOG_DIR/mdsl.$id.log" > /dev/null &
        done
        echo "Start MDSL server done."
    else
        ipnr=`cat $CONFIG_FILE | grep "mdsl:.*:$1\$" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do 
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$MDSL_CMD $HVFS_HOME/test/xnet/mdsl.ut $id $R2IP $port > $LOG_DIR/mdsl.$id.log" > /dev/null &
            echo "Start MDSL server $id done."
        done
    fi
}

function start_osd() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do 
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$OSD_CMD $HVFS_HOME/test/xnet/osd.ut $id $R2IP $port > $LOG_DIR/osd.$id.log" > /dev/null &
        done
        echo "Start OSD server done."
    else
        ipnr=`cat $CONFIG_FILE | grep "osd:.*:$1\$" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do 
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$OSD_CMD $HVFS_HOME/test/xnet/osd.ut $id $R2IP $port > $LOG_DIR/osd.$id.log" > /dev/null &
            echo "Start OSD server $id done."
        done
    fi
}

function start_mds() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$MDS_CMD $HVFS_HOME/test/xnet/mds.ut $id $R2IP $port > $LOG_DIR/mds.$id.log" > /dev/null &
        done
        echo "Start MDS server done."
    else
        ipnr=`cat $CONFIG_FILE | grep "mds:.*:$1\$" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$MDS_CMD $HVFS_HOME/test/xnet/mds.ut $id $R2IP $port > $LOG_DIR/mds.$id.log" > /dev/null &
            echo "Start MDS server $id done."
        done
    fi
}

function start_bp() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "bp:" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "id=$id root=$R2IP realport=$port $HVFS_HOME/test/xnet/bp.ut $id > $LOG_DIR/bp.$id.log" > /dev/null &
        done
        echo "Start BP server done."
    else
        ipnr=`cat $CONFIG_FILE | grep "bp:.*:$1\$" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "id=$id root=$R2IP realport=$port $HVFS_HOME/test/xnet/bp.ut $id > $LOG_DIR/bp.$id.log" > /dev/null &
            echo "Start BP server $id done."
        done
    fi
}

function start_root() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$ROOT_CMD $HVFS_HOME/test/xnet/root.ut $id $CONFIG_FILE $port > $LOG_DIR/root.$id.log" > /dev/null &
        done
        echo "Start R2 server done. Waiting for 5 seconds to clean up latest instance..."
    else
        ipnr=`cat $CONFIG_FILE | grep "r2:.*:$1\$" | awk -F: '{print $2":"$4":"$3}'`
        for x in $ipnr; do
            ip=`echo $x | awk -F: '{print $1}'`
            id=`echo $x | awk -F: '{print $2}'`
            port=`echo $x | awk -F: '{print $3}'`
            $SSH $UN$ip "$ROOT_CMD $HVFS_HOME/test/xnet/root.ut $id $CONFIG_FILE $port > $LOG_DIR/root.$id.log" > /dev/null &
            echo "Start R2 server $id done. Waiting for 5 seconds to clean up latest instance..."
        done
    fi
    sleep 5
}

function start_r2cli() {
    if [ "x$1" == "x" ]; then
        hint=""
    else
        hint=$1
    fi

    if [ "x$2" == "x" ]; then
        hint2=".*"
    else
        hint2=$2
    fi

    ipnr=`cat $CONFIG_FILE | grep "client:.*$hint:$hint2:.*" | awk -F: '{print $2":"$4":"$3}'`
    for x in $ipnr; do
        ip=`echo $ipnr | awk -F: '{print $1}'`
        id=`echo $ipnr | awk -F: '{print $2}'`
        port=`echo $ipnr | awk -F: '{print $3}'`
        $SSH $UN$ip "type=1 fsid=0 op=1 $HVFS_HOME/test/xnet/r2cli.ut $id $R2IP $port"
        break
    done
}

function check_mdsl() {
    ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        R=`$SSH $UN$ip "cat $LOG_DIR/mdsl.$id.log | grep UP"`
        if [ "x$R" == "x" ]; then
            echo "MDSL $id is not alive, please check it!"
        fi
    done
}

function check_osd() {
    ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        R=`$SSH $UN$ip "cat $LOG_DIR/osd.$id.log | grep UP"`
        if [ "x$R" == "x" ]; then
            echo "OSD $id is not alive, please check it!"
        fi
    done
}

function check_mds() {
    ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        R=`$SSH $UN$ip "cat $LOG_DIR/mds.$id.log | grep UP"`
        if [ "x$R" == "x" ]; then
            echo "MDS $id is not alive, please check it!"
        fi
    done
}

function check_bp() {
    ipnr=`cat $CONFIG_FILE | grep "bp:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        R=`$SSH $UN$ip "cat $LOG_DIR/bp.$id.log | grep UP"`
        if [ "x$R" == "x" ]; then
            echo "MDS $id is not alive, please check it!"
        fi
    done
}

function check_root() {
    ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        R=`$SSH $UN$ip "cat $LOG_DIR/root.$id.log | grep UP"`
        if [ "x$R" == "x" ]; then
            echo "R2 $id is not alive, please check it!"
        fi
    done
}

function check_all() {
    echo "'check' is not reliable, please use 'stat' instead."
    check_root
    check_mds
    check_mdsl
    check_osd
}

function stop_mdsl() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "mdsl:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "mdsl.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -s SIGHUP $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 5
}

function stop_osd() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "osd:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "osd.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -s SIGHUP $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 5
}

function stop_mds() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "mds:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "mds.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -s SIGHUP $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 2
}

function stop_bp() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "bp:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "bp:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "bp.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
         $SSH $UN$ip "kill -s SIGHUP $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 2
}

function stop_root() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "r2:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi
    sleep 2
    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "root.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -s SIGHUP $PID 2>&1 > /dev/null" > /dev/null
    done
}

function kill_mdsl() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "mdsl:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "mdsl.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 5
}

function kill_osd() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "osd:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "osd.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 5
}

function kill_mds() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "mds:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "mds.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 2
}

function kill_bp() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "bp:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "bp:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi

    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "bp.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
    done
    sleep 2
}

function kill_root() {
    if [ "x$1" == "x" ]; then
        ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4}'`
    else
        ipnr=`cat $CONFIG_FILE | grep "r2:.*:$1\$" | awk -F: '{print $2":"$4}'`
    fi
    sleep 2
    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        PID=`$SSH $UN$ip "ps aux" | grep "root.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
    done
}

function start_all() {
    start_root
    start_mdsl
    start_mds
    start_osd
}

function stop_all() {
    stop_osd
    stop_mds
    stop_mdsl
    stop_root
}

function kill_all() {
    kill_osd
    kill_mdsl
    kill_mds
    kill_root
}

function do_clean() {
    ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4}'`

    for x in $ipnr; do
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        $SSH $UN$ip "rm -rf /tmp/hvfs/4*" > /dev/null
        $SSH $UN$ip "rm -rf /tmp/hvfs/6*" > /dev/null
        $SSH $UN$ip "rm -rf /tmp/hvfs/a*" > /dev/null
        $SSH $UN$ip "rm -rf /tmp/hvfs/bp" > /dev/null
        $SSH $UN$ip "rm -rf /tmp/hvfs/*_store" > /dev/null
        $SSH $UN$ip "rm -rf /tmp/.MDS.DCONF.*" > /dev/null
    done
}

function stat_mdsl() {
    echo "----------MDSL----------"
    ipnr=`cat $CONFIG_FILE | grep "mdsl:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "mdsl.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "MDSL $id is running."
        else
            echo "MDSL $id is gone."
        fi
    done
}

function stat_osd() {
    echo "----------OSD-----------"
    ipnr=`cat $CONFIG_FILE | grep "osd:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "osd.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "OSD  $id is running."
        else
            echo "OSD  $id is gone."
        fi
    done
}

function stat_mds() {
    echo "----------MDS----------"
    ipnr=`cat $CONFIG_FILE | grep "mds:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "mds.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "MDS  $id is running."
        else
            echo "MDS  $id is gone."
        fi
    done
}

function stat_bp() {
    echo "----------BP----------"
    ipnr=`cat $CONFIG_FILE | grep "bp:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "bp.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "BP   $id is running."
        else
            echo "BP   $id is gone."
        fi
    done
}

function stat_root() {
    echo "----------R2----------"
    ipnr=`cat $CONFIG_FILE | grep "r2:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "root.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "R2   $id is running."
        else
            echo "R2   $id is gone."
        fi
    done
}

function stat_client() {
    echo "----------CLIENT----------"
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4}'`
    for x in $ipnr; do 
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        NR=`$SSH $UN$ip "ps aux" | grep "client.ut $id" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep | wc -l`
        if [ "x$NR" == "x1" ]; then
            echo "CLT  $id is running."
        else
            echo "CLT  $id is gone."
        fi
    done
}

function gather_rps() {
    ARGS=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$"`
    NR=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`

    # issue cmd to clients now
    I=0
    RPS_TOTAL=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        RES=`$SSH $UN$ip "grep \"Aggr IOPS\" $LOG_DIR/client.$id.log"`

        OP=`echo $RES | sed -e 's/.*op=\(.*\)].*/\1/g'`
        RPS=`echo $RES | awk '{print $5}'`
        # prepare the arguments
        if [ "x$OP" == "x" ]; then
            OP=0
            RPS=0
        fi
        if [ $OP -eq 100 ]; then
            RPS_TOTAL=`echo "$RPS_TOTAL + $RPS * 3" | bc -l`
        elif [ $OP -eq 200 ]; then
            RPS_TOTAL=`echo "$RPS_TOTAL + $RPS * 5" | bc -l`
        else
            RPS_TOTAL=`echo "$RPS_TOTAL + $RPS" | bc -l`
        fi
        let I+=1
    done
    echo "Aggr RPS: $RPS_TOTAL OP/s"
}

function repeat_ut() {
    RND=1
    while true;
    do
        sleep 5
        stat_client > rut.log
        RES=`cat rut.log | grep running`
        if [ "x$RES" == "x" ]; then
            # dump the Aggr RPS
            if [ $RND -gt 1 ]; then
                gather_rps
            fi
            echo "Repeat unit test, round $RND start ..."
            let RND+=1
            do_ut
        fi
    done
    rm -rf rut.log
}

function do_status() {
    echo "Checking servers' status ..."
    stat_mdsl
    stat_mds
    stat_osd
    stat_root
}

function do_ut() {
    ARGS=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$"`
    NR=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`
    # prepare the client cmd environment variables
    CLIENT_CMD="LOG_DIR=$LOG_DIR "`echo $ARGS | sed -e "s/nr=[-0-9]*//g"`

    # start clients now
    I=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        $SSH $UN$ip "$CLIENT_CMD $HVFS_HOME/test/xnet/client.ut $id $R2IP $port > $LOG_DIR/client.$id.log" > /dev/null &
        let I+=1
    done
    echo "Start $NR UT client(s) running."
}

function do_kut() {
    ARGS=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$"`
    NR=`cat $HVFS_HOME/conf/ut.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`
    # kill active clients now
    I=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        PID=`$SSH $UN$ip "ps aux | grep \"client.ut $id\" | grep -v bash | grep -v ssh | grep -v expect | grep -v grep"`
        $SSH $UN$ip "kill -9 $PID 2>&1 > /dev/null" > /dev/null
        let I+=1
    done
}

function do_mount_pfs() {
    ARGS=`cat $HVFS_HOME/conf/pfs.conf | grep -v "^ *#" | grep -v "^$"`
    NR=`cat $HVFS_HOME/conf/pfs.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`
    # prepare the client cmd environment variables
    CLIENT_CMD=`echo $ARGS | sed -e "s/nr=[-0-9]*//g"`

    if [ "x$ENTRY_TO" == "x" ]; then
        ENTRY_TO=1
    fi
    if [ "x$ATTR_TO" == "x" ]; then
        ATTR_TO=1
    fi
    if [ "x$PFS_ROOT" == "x" ]; then
        PFS_ROOT="/mnt/hvfs"
    fi

    # start clients now
    I=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        $SSH $UN$ip "$MNT_OPT $CLIENT_CMD root=$R2IP id=$id $HVFS_HOME/test/xnet/pfs.ut $PFS_ROOT -o allow_other -o use_ino -o entry_timeout=$ENTRY_TO -o attr_timeout=$ATTR_TO -f > $LOG_DIR/pfs.$id.log" > /dev/null &
        let I+=1
    done
    echo "Start $NR PFS fuse client(s) running."
}

function do_umount_pfs() {
    ARGS=`cat $HVFS_HOME/conf/pfs.conf | grep -v "^ *#" | grep -v "^$"`
    NR=`cat $HVFS_HOME/conf/pfs.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi
    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`
    # prepare the client cmd environment variables
    CLIENT_CMD=`echo $ARGS | sed -e "s/nr=[-0-9]*//g"`

    if [ "x$PFS_ROOT" == "x" ]; then
        PFS_ROOT="/mnt/hvfs"
    fi

    # start clients now
    I=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        $SSH $UN$ip "$CLIENT_CMD"' `which fusermount` '"-u $PFS_ROOT" > /dev/null &
        let I+=1
    done
    echo "Start $NR PFS fuse client(s) running."
}

function do_list_pfs() {
    NR=`cat $HVFS_HOME/conf/pfs.conf | grep -v "^ *#" | grep -v "^$" | grep 'nr=' | sed -e 's/nr=//g'`
    TOTAL=`cat $CONFIG_FILE | grep "client:" | wc -l`
    if [ "x$NR" == 'x-1' ]; then
        NR=$TOTAL
    elif [ "x$NR" == "x" ]; then
        NR=0
    fi

    ipnr=`cat $CONFIG_FILE | grep "client:" | awk -F: '{print $2":"$4":"$3}'`

    if [ "x$PFS_ROOT" == "x" ]; then
        PFS_ROOT="/mnt/hvfs"
    fi

    # start clients now
    I=0
    for x in $ipnr; do
        if [ $I -ge $NR ]; then
            break
        fi
        ip=`echo $x | awk -F: '{print $1}'`
        id=`echo $x | awk -F: '{print $2}'`
        port=`echo $x | awk -F: '{print $3}'`
        echo -n "[$ip] "
        $SSH $UN$ip `which mount` -l | grep "$PFS_ROOT"
        let I+=1
    done
}

function pview() {
    if [ "x$1" == "x" ]; then
        exec $SSH $UN$R2IP tail -f $LOG_DIR/CP-BACK-root.0.mds
    elif [ "x$1" == "xmds" ]; then
        exec $SSH $UN$R2IP tail -f $LOG_DIR/CP-BACK-root.0.mds
    elif [ "x$1" == "xmdsl" ]; then
        exec $SSH $UN$R2IP tail -f $LOG_DIR/CP-BACK-root.0.mdsl
    elif [ "x$1" == "xosd" ]; then
        exec $SSH $UN$R2IP tail -f $LOG_DIR/CP-BACK-root.0.osd
    fi
}

function do_help() {
    echo "Version 1.0.1b"
    echo "Copyright (c) 2010-2012 Can Ma <ml.macana@gmail.com>"
    echo ""
    echo "Usage: hvfs.sh [start|stop|kill|check] [mds|mdsl|osd|r2|bp|all] [id]"
    echo "               [clean|stat]"
    echo "               [ut|kut|sut]"
    echo "               [mount|umount|ml]"
    echo ""
    echo "Commands:"
    echo "      start [t] [id]  start servers"
    echo "      stop [t] [id]   stop servers"
    echo "      kill [t] [id]   kill servers"
    echo "      check [t] [id]  check servers' status"
    echo "      clean           clean the STOREGE home"
    echo "      stat            get and print servers' status"
    echo "      ut              do file system UNIT TEST"
    echo "                      NOTE: you have to in MODE=fs"
    echo "      kut             kill the unit test programs"
    echo "      sut             stat the unit test programs"
    echo "      mount           mount the fuse client"
    echo "      umount          umount the fuse client"
    echo "      ml              list the mounted pfs entry"
    echo "      pview [mds |"
    echo "             osd |"
    echo "             mdsl]    view the aggregated R2 log"
    echo ""
    echo "Environments:"
    echo "      HVFS_HOME       default to the current path."
    echo "                      Note that, if you boot servers on other nodes, "
    echo "                      you have to ensure that all the binaries are "
    echo "                      in the right pathname (same as this node)."
    echo "      MODE            fs: file system mode."
    echo "                      kv: key value mode."
    echo "      LOG_DIR         default to ~"
    echo ""
    echo "      USERNAME        default user name for each ssh connection."
    echo "      PASSWD          default passwd for each ssh connection."
    echo ""
    echo "Examples:"
    echo "1. start all the servers in config file."
    echo "   $ hvfs.sh start"
    echo "2. start MDS 1"
    echo "   $ hvfs.sh start mds 1"
    echo "3. stop MDS 1"
    echo "   $ hvfs.sh stop mds 1"
    echo "4. stop all the servers"
    echo "   $ hvfs.sh stop"
    echo "5. get the current status"
    echo "   $ hvfs.sh stat"
    echo "6. run into the file system mode."
    echo "   $ MODE=fs hvfs.sh start"
}

if [ "x$1" == "xstart" ]; then
    if [ "x$2" == "xmds" ]; then
        start_mds $3
    elif [ "x$2" == "xmdsl" ]; then
        start_mdsl $3
    elif [ "x$2" == "xosd" ]; then
        start_osd $3
    elif [ "x$2" == "xr2" ]; then
        start_root $3
    elif [ "x$2" == "xbp" ]; then
        start_bp $3
    else
        start_all
    fi
elif [ "x$1" == "xstop" ]; then
    if [ "x$2" == "xmds" ]; then
        stop_mds $3
    elif [ "x$2" == "xmdsl" ]; then
        stop_mdsl $3
    elif [ "x$2" == "xosd" ]; then
        stop_osd $3
    elif [ "x$2" == "xr2" ]; then
        stop_root $3
    elif [ "x$2" == "xbp" ]; then
        stop_bp $3
    else
        stop_all
    fi
elif [ "x$1" == "xkill" ]; then
    if [ "x$2" == "xmds" ]; then
        kill_mds
    elif [ "x$2" == "xmdsl" ]; then
        kill_mdsl
    elif [ "x$2" == "xosd" ]; then
        kill_osd
    elif [ "x$2" == "xr2" ]; then
        kill_root
    elif [ "x$2" == "xbp" ]; then
        kill_bp
    else
        kill_all
    fi
elif [ "x$1" == "xcheck" ]; then
    if [ "x$2" == "xmds" ]; then
        check_mds
    elif [ "x$2" == "xmdsl" ]; then
        check_mdsl
    elif [ "x$2" == "xosd" ]; then
        check_osd
    elif [ "x$2" == "xr2" ]; then
        check_root
    elif [ "x$2" == "xbp" ]; then
        check_bp
    else
        check_all
    fi
elif [ "x$1" == "xut" ]; then
    do_ut_conf_check
    echo "There are many unit test parameters, please see the config file in 'conf/ut.conf'."
    do_ut
    while true;
    do
        sleep 5
        stat_client > ut.log
        RES=`cat ut.log | grep running`
        if [ "x$RES" == "x" ]; then
            gather_rps
            break;
        fi
    done
    rm -rf ut.log
elif [ "x$1" == "xkut" ]; then
    do_ut_conf_check
    do_kut
elif [ "x$1" == "xsut" ]; then
    do_ut_conf_check
    stat_client
elif [ "x$1" == "xstat" ]; then
    if [ "x$2" == "x" ]; then
        do_status
    elif [ "x$2" == "xbp" ]; then
        stat_bp
    fi
elif [ "x$1" == "xrut" ]; then
    repeat_ut
elif [ "x$1" == "xclean" ]; then
    do_clean
elif [ "x$1" == "xrestart" ]; then
    stop_all
    start_all
elif [ "x$1" == "xsyn" ]; then
    adjust_syn
elif [ "x$1" == "xmount" ]; then
    do_mount_pfs
elif [ "x$1" == "xumount" ]; then
    do_umount_pfs
elif [ "x$1" == "xml" ]; then
    do_list_pfs
elif [ "x$1" == "xmkfs" ]; then
    start_r2cli $2 $3
elif [ "x$1" == "xpview" ]; then
    pview $2
elif [ "x$1" == "xhelp" ]; then
    do_help
else
    do_help
fi
