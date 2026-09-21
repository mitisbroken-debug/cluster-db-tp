#!/bin/bash
set -e

PGDATA="/var/lib/postgresql/data"

if [ -z "$(ls -A "$PGDATA" 2>/dev/null)" ]; then
  echo "Nodo secundario: clonando datos desde node1..."

  until pg_isready -h node1 -p 5432 -U replicacion > /dev/null 2>&1; do
    echo "Esperando a que node1 este listo..."
    sleep 2
  done

  gosu postgres bash -c "PGPASSWORD='${REPL_PASSWORD}' pg_basebackup -h node1 -D '${PGDATA}' -U replicacion -Fp -Xs -P -R"
fi

exec docker-entrypoint.sh postgres
