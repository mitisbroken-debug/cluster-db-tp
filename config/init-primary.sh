#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPL_PASSWORD}';
  CREATE USER administrador WITH SUPERUSER PASSWORD '${ADMIN_PASSWORD}';
  CREATE USER monitorizacion WITH PASSWORD '${MONITOR_PASSWORD}';
  GRANT pg_monitor TO monitorizacion;
EOSQL