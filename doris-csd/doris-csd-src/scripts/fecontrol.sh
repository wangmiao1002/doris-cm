#!/bin/bash

#set -ex

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

log "Running Doris Frontend CSD control script..."
log "Got command as $1"

case $1 in
  (start)
    #Set java path
    if [ -n "$JAVA_HOME" ]; then
      log "JAVA_HOME added to path as $JAVA_HOME"
      export PATH=$JAVA_HOME/bin:$PATH
    else
      log "JAVA_HOME not set"
    fi
    log "jvm size: $DORIS_FE_MEMORY"
    export JAVA_OPTS="-Xmx$DORIS_FE_MEMORY"
    export DORIS_HOME=$DORIS_HOME/fe
    while read line; do
		envline=$(echo $line | sed 's/[[:blank:]]*=[[:blank:]]*/=/g' | sed 's/^[[:blank:]]*//g' | egrep "^[[:upper:]]([[:upper:]]|_|[[:digit:]])*=")
		envline=$(eval "echo $envline")
		if [[ $envline == *"="* ]]; then
                   eval 'export "$envline"'
		fi
    done < $CONF_DIR/conf/fe.conf
    if [ -e $DORIS_HOME/bin/palo_env.sh ]; then
        source $DORIS_HOME/bin/palo_env.sh
    fi
    
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
    final_java_opt=$JAVA_OPTS
    log "using java version $java_version" 
    log $final_java_opt
    DORIS_FE_JAR=
    for f in $DORIS_HOME/lib/*.jar; do
	if [[ "${f}" == *"doris-fe.jar" ]]; then
        	DORIS_FE_JAR="${f}"
        	continue
    	fi
        CLASSPATH=$f:${CLASSPATH}
    done
    CLASSPATH="${DORIS_FE_JAR}:${CLASSPATH}"
    export CLASSPATH="${CLASSPATH}:${DORIS_HOME}/lib:${CONF_DIR}/conf"
    export DORIS_HOME=$CONF_DIR
    export PID_DIR=$CONF_DIR
    log "first stat enable : $DORIS_FE_FIRST_LIVE"
    if [[ $DORIS_FE_FIRST_LIVE = "true" ]];
    then
         log "Frist Starting the Doris Frontend, MasterIP:$DORIS_FE_MASTER_IP ; port :$DORIS_FE_MASTER_PORT"
         exec $JAVA $final_java_opt -XX:OnOutOfMemoryError="kill -9 %p" org.apache.doris.PaloFe -helper $DORIS_FE_MASTER_IP:$DORIS_FE_MASTER_PORT
    else
         log "Starting the Doris Frontend"
         exec  $JAVA $final_java_opt -XX:OnOutOfMemoryError="kill -9 %p" org.apache.doris.PaloFe
    fi
    ;;
  (*)
    echo "Don't understand [$1]"
    exit 1
    ;;
esac
