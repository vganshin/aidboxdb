#!/bin/bash
set -e
set -o xtrace

export PGDATA=/data/pg
export GOOGLE_APPLICATION_CREDENTIALS="/secrets/gcp.json"

echo "Data dir: $PGDATA"

if [ ! -s "/data/pg" ]; then

    cat <<-CONF > /data/.env
export WALG_GS_PREFIX="$WALG_GS_PREFIX"
export GOOGLE_APPLICATION_CREDENTIALS="/secrets/gcp.json"
CONF

   cat <<-CONF > /data/restore_command.sh
#!/bin/bash
source /data/.env
/pg/bin/wal-g wal-fetch \$1 \$2

CONF

chmod a+x /data/restore_command.sh


/pg/bin/wal-g backup-fetch /data/pg LATEST

cat <<-CONF >> /data/pg/recovery.conf
standby_mode = 'on'
restore_command = '/data/restore_command.sh %f %p'
CONF


fi

exec postgres
