#!/bin/bash

#set -ex

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

log "Running Doris Backend  CSD control script..."
log "Got command as $1"

case $1 in
  (start)
    #Set java path
    export DORIS_LIB=$DORIS_HOME/be
    if [[ "$(uname -s)" != 'Darwin' ]]; then
    	MAX_MAP_COUNT="$(cat /proc/sys/vm/max_map_count)"
    	if [[ "${MAX_MAP_COUNT}" -lt 2000000 ]]; then
        	echo "Please set vm.max_map_count to be 2000000 under root using 'sysctl -w vm.max_map_count=2000000'."
        	exit 1
    	fi
    fi
    export ODBCSYSINI=$CONF_DIR/conf
    export NLS_LANG='AMERICAN_AMERICA.AL32UTF8'
    for f in "${DORIS_LIB}/lib"/*.jar; do
    	if [[ -z "${DORIS_JNI_CLASSPATH_PARAMETER}" ]]; then
        	export DORIS_JNI_CLASSPATH_PARAMETER="${f}"
    	else
        	export DORIS_JNI_CLASSPATH_PARAMETER="${f}:${DORIS_JNI_CLASSPATH_PARAMETER}"
    	fi
    done
    # DORIS_JNI_CLASSPATH_PARAMETER is used to configure additional jar path to jvm. e.g. -Djava.class.path=$DORIS_HOME/lib/java-udf.jar
    export DORIS_JNI_CLASSPATH_PARAMETER="-Djava.class.path=${DORIS_JNI_CLASSPATH_PARAMETER}"
    export UDF_RUNTIME_DIR
    export LSAN_OPTIONS="suppressions=${CONF_DIR}/conf/asan_suppr.conf"
    while read line; do
		envline=$(echo $line | sed 's/[[:blank:]]*=[[:blank:]]*/=/g' | sed 's/^[[:blank:]]*//g' | egrep "^[[:upper:]]([[:upper:]]|_|[[:digit:]])*=")
		envline=$(eval "echo $envline")
		if [[ $envline == *"="* ]]; then
                   eval 'export "$envline"'
		fi
    done < $CONF_DIR/conf/be.conf
    if [[ -z "${JAVA_HOME}" ]]; then
    	echo "The JAVA_HOME environment variable is not defined correctly"
    	echo "This environment variable is needed to run this program"
    	echo "NB: JAVA_HOME should point to a JDK not a JRE"
    	echo "You can set it in be.conf"
    	exit 1
    fi
    if [ -e $DORIS_LIB/bin/palo_env.sh ]; then
        source $DORIS_LIB/bin/palo_env.sh
    fi
    if [ ! -d $UDF_RUNTIME_DIR ]; then
    	mkdir ${UDF_RUNTIME_DIR}
    fi
    rm -f ${UDF_RUNTIME_DIR}/*
    export PID_DIR=$CONF_DIR
    if [[ "${RUN_IN_AWS}" -eq 0 ]]; then
    	export AWS_EC2_METADATA_DISABLED=true
    fi

    ## set asan and ubsan env to generate core file
    export ASAN_OPTIONS=symbolize=1:abort_on_error=1:disable_coredump=0:unmap_shadow_on_exit=1
    export UBSAN_OPTIONS=print_stacktrace=1
    export LIBHDFS3_CONF="${CONF_DIR}/conf/hdfs-site.xml"
    set_tcmalloc_heap_limit() {
    	local total_mem_mb
    	local mem_limit_str

    	if [[ "$(uname -s)" != 'Darwin' ]]; then
        	total_mem_mb="$(free -m | grep Mem | awk '{print $2}')"
    	else
        	total_mem_mb="$(($(sysctl -a hw.memsize | awk '{print $NF}') / 1024))"
    	fi
    		mem_limit_str=$(grep ^mem_limit "${CONF_DIR}"/conf/be.conf)
    	local digits_unit=${mem_limit_str##*=}
    	digits_unit="${digits_unit#"${digits_unit%%[![:space:]]*}"}"
    	digits_unit="${digits_unit%"${digits_unit##*[![:space:]]}"}"
    	local digits=${digits_unit%%[^[:digit:]]*}
    	local unit=${digits_unit##*[[:digit:] ]}

    	mem_limit_mb=0
    	case ${unit} in
    	t | T) mem_limit_mb=$((digits * 1024 * 1024)) ;;
    	g | G) mem_limit_mb=$((digits * 1024)) ;;
    	m | M) mem_limit_mb=$((digits)) ;;
    	k | K) mem_limit_mb=$((digits / 1024)) ;;
    	%) mem_limit_mb=$((total_mem_mb * digits / 100)) ;;
    	*) mem_limit_mb=$((digits / 1024 / 1024 / 1024)) ;;
    	esac

    	if [[ "${mem_limit_mb}" -eq 0 ]]; then
        	mem_limit_mb=$((total_mem_mb * 90 / 100))
    	fi

    	if [[ "${mem_limit_mb}" -gt "${total_mem_mb}" ]]; then
        	echo "mem_limit is larger than whole memory of the server. ${mem_limit_mb} > ${total_mem_mb}."
        	return 1
    	fi
    	export TCMALLOC_HEAP_LIMIT_MB=${mem_limit_mb}
    } 
    # see https://github.com/jemalloc/jemalloc/issues/2366
    export JEMALLOC_CONF="percpu_arena:percpu,background_thread:true,metadata_thp:auto,muzzy_decay_ms:30000,dirty_decay_ms:30000,oversize_threshold:0,lg_tcache_max:16,prof:true,prof_prefix:jeprof.out"
    cp -a $DORIS_LIB/www $CONF_DIR/
    export DORIS_HOME=$CONF_DIR
    log "start time: "$(date)
    if [ ! -f /bin/limit3 ]; then
    	LIMIT=
    else
    	LIMIT="/bin/limit3 -c 0 -n 65536"
    fi
    log "Starting the Doris Backend"
    exec ${LIMIT:+${LIMIT}} ${DORIS_LIB}/lib/doris_be
    ;;
  (*)
    echo "Don't understand [$1]"
    exit 1
    ;;
esac
