#!/bin/bash
set -e

HOST="proxy"
PORT="5432"
USER="administrador"
DB="clusterdb"
DURATION=30
REPETICIONES=3
NIVELES=(10 25 50 100 200)

OUTFILE="resultados_benchmark.csv"
echo "concurrencia,repeticion,tps,latencia_promedio_ms" > "$OUTFILE"

for c in "${NIVELES[@]}"; do
  for r in $(seq 1 $REPETICIONES); do
    echo "=== Concurrencia $c, repeticion $r ==="
    RESULTADO=$(timeout 120 bash -c "PGPASSWORD=admin123 pgbench -c $c -j 4 -T $DURATION -h $HOST -p $PORT -U $USER $DB 2>&1" || true)
    echo "$RESULTADO"
    TPS=$(echo "$RESULTADO" | grep "tps = " | tail -1 | awk '{print $3}')
    LAT=$(echo "$RESULTADO" | grep "latency average" | awk '{print $4}')
    if [ -z "$TPS" ]; then TPS="0"; fi
    if [ -z "$LAT" ]; then LAT="0"; fi
    echo "$c,$r,$TPS,$LAT" >> "$OUTFILE"
  done
done

echo "Listo. Resultados en $OUTFILE"
