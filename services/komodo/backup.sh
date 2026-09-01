#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
# db name is literally "postgres"; only the user comes from .env.
#
# cron.job_run_details is pg_cron's execution log. DocumentDB schedules two index-build
# tasks on a "2 seconds" interval, so it grows ~89k rows/day (~15 MB) forever and nothing
# ever reads it -- it reached 6.8 GB of a 7.1 GB database before this was caught. A
# purge job (cron.schedule 'purge-cron-history') caps it at 7 days server-side; this
# exclusion is the second line of defence, so the backup stays small even if that job is
# dropped by a DocumentDB upgrade.
#
# -table-DATA, not -table: cron.job holds the schedules themselves (including the purge
# job) and must keep being dumped. Only the run log is dropped. The table is recreated on
# restore by CREATE EXTENSION pg_cron, not by DDL in this dump.
dump_postgres postgres "${KOMODO_DB_USERNAME}" postgres \
    --exclude-table-data='cron.job_run_details'

