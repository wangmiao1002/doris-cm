#!/bin/bash

#set -ex

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

log "Running Doris Broker CSD control script..."
log "Got command as $1"

case $1 in
  (start)
    #Set java path
    log "jvm size: ${BROKER_MAX_HEAPSIZE}"
    export JAVA_OPTS="-Xmx$BROKER_MAX_HEAPSIZE -Dfile.encoding=UTF-8"
    if [ -n "$JAVA_HOME" ]; then
      log "JAVA_HOME added to path as $JAVA_HOME"
      export PATH=$JAVA_HOME/bin:$PATH
    else
      log "JAVA_HOME not set"
    fi
    export BROKER_HOME=$DORIS_HOME/apache_hdfs_broker
    export BROKER_LOG_DIR=$BROKER_LOG_DIR
    while read line; do
		envline=$(echo $line | sed 's/[[:blank:]]*=[[:blank:]]*/=/g' | sed 's/^[[:blank:]]*//g' | egrep "^[[:upper:]]([[:upper:]]|_|[[:digit:]])*=")
		envline=$(eval "echo $envline")
		if [[ $envline == *"="* ]]; then
                   eval 'export "$envline"'
		fi
    done < $CONF_DIR/conf/apache_hdfs_broker.conf
    if [ -z "$JAVA_HOME" ]; then
        JAVA=$(which java)
    else
        JAVA="$JAVA_HOME/bin/java"
    fi
    
    if [ ! -x "$JAVA" ]; then
        echo "The JAVA_HOME environment variable is not defined correctly"
        echo "This environment variable is needed to run this program"
        echo "NB: JAVA_HOME should point to a JDK not a JRE"
        exit 1
    fi
    for f in $BROKER_HOME/lib/*.jar; do
        CLASSPATH=$f:${CLASSPATH}
    done
    export CLASSPATH=${CLASSPATH}:${DORIS_HOME}/lib:$CONF_DIR/conf
    export PID_DIR=$CONF_DIR
    log "Starting the Doris Broker"
    exec $LIMIT $JAVA $JAVA_OPTS org.apache.doris.broker.hdfs.BrokerBootstrap
    ;;
  (*)
    echo "Don't understand [$1]"
    exit 1
    ;;
esac
