#!/bin/bash
set -e
set -o xtrace

export LD_LIBRARY_PATH=/pg/lib

file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

PATH=/pg/bin/:$PATH

if [ "${1:0:1}" = '-' ]; then
	  set -- postgres "$@"
fi


PGDATA=/data

NUM_ATTEMPTS=20
NODE_NAME=$PG_REPLICA


if [ ! -s "/data/PG_VERSION" ]; then

    if [ "$PG_ROLE" = 'replica' ]; then

        echo "$PG_MASTER_HOST:5432:*:postgres:$POSTGRES_PASSWORD" > ~/.pgpass
        chmod 0600 ~/.pgpass

        n=0
        until [ $n -ge $NUM_ATTEMPTS ]
        do
            pg_basebackup -D /data -Fp -U postgres -w -R -Xs -c fast -l 'clone'  -P -v -h $PG_MASTER_HOST -U postgres  && export RESTORED=1 && break
            n=$[$n+1]
            echo "Not ready; Sleep $n"
            sleep $n
        done

        psql -h $PG_MASTER_HOST -U postgres -w -c "SELECT pg_create_physical_replication_slot('$NODE_NAME');" || echo "may be exists"

        echo "restored: $RESTORED"

        echo 'hot_standby = on' >> /data/postgresql.conf
        echo 'port = 5432' >> /data/postgresql.conf
        echo "primary_slot_name = '$NODE_NAME'" >> /data/recovery.conf
        echo "standby_mode = 'on'" >> /data/recovery.conf

	      echo
	      echo 'PostgreSQL clone process complete; ready for start up.'
	      echo

  else

    mkdir -p /data
    chmod 700 /data
    # chown -R postgres /data

    file_env 'POSTGRES_INITDB_ARGS'
    export LD_LIBRARY_PATH=/pg/lib && /pg/bin/initdb --data-checksums -E 'UTF-8' --lc-collate='en_US.UTF-8' --lc-ctype='en_US.UTF-8' -D /data

    # check password first so we can output the warning before postgres
    # messes it up
    file_env 'POSTGRES_PASSWORD'
    pass="PASSWORD '$POSTGRES_PASSWORD'"
    authMethod=md5

    { echo; echo "host all all all $authMethod"; } | tee -a "$PGDATA/pg_hba.conf" > /dev/null
    { echo; echo "host replication postgres 0.0.0.0/0 $authMethod"; } | tee -a "$PGDATA/pg_hba.conf" > /dev/null

    { echo; echo "listen_addresses = '*'"; } | tee -a "$PGDATA/postgresql.conf" > /dev/null


    export LD_LIBRARY_PATH=/pg/lib && /pg/bin/pg_ctl -D /data  -w start
    export LD_LIBRARY_PATH=/pg/lib && /pg/bin/createuser -s postgres

    echo "ALTER USER root WITH SUPERUSER $pass" | /pg/bin/psql postgres

    if [ -n "$POSTGRES_DB"  ] && [ "$POSTGRES_DB" != 'postgres' ]; then
        /pg/bin/psql postgres -c "create database $POSTGRES_DB"
    fi

    # shared_preload_libraries='pg_pathman'
    # Some tweaks to default configuration
    cat <<-CONF >> /data/postgresql.conf
        listen_addresses = '*'
        synchronous_commit = off
        shared_buffers = '2GB'
        wal_log_hints = on
        wal_level = logical
        max_wal_senders = 30
        max_replication_slots = 30
        max_wal_size = '4GB'
     
        shared_preload_libraries = 'pg_stat_statements, pipelinedb'
        max_worker_processes = 128
        pg_stat_statements.max = 500
        pg_stat_statements.track = top
        pg_stat_statements.track_utility = true
        pg_stat_statements.save = false

        # #Also consider enabling io timing traction by uncommenting this:
        track_io_timing = on
CONF


    export LD_LIBRARY_PATH=/pg/lib && /pg/bin/pg_ctl -D /data -m fast -w stop

    echo
    echo 'PostgreSQL init process complete; ready for start up.'
    echo

  fi
fi


mkdir -p /data
chmod 700 /data
if [ -O /data ]; then
    echo 'Owned by right user!';
else
    echo "Change to root"
    chown -R root /data;
fi

echo "postgres"
exec postgres

