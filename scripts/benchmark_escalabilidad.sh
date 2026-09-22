#!/bin/bash
set -e

DURATION=30
CLIENTES=50

mkdir -p /tmp/benchmark-results

echo "=== 1 nodo (solo node1, sin r??plicas) ==="
PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node1 -p 5432 -U aplicacion clusterdb | tee /tmp/benchmark-results/1nodo.txt

echo ""
echo "=== 2 nodos (node1 + node2 en paralelo) ==="
(PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node1 -p 5432 -U aplicacion clusterdb) &
PID1=$!
(PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node2 -p 5432 -U aplicacion clusterdb) &
PID2=$!
wait $PID1 $PID2
echo "Dos nodos listo"

echo ""
echo "=== 3 nodos (node1 + node2 + node3 en paralelo) ==="
(PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node1 -p 5432 -U aplicacion clusterdb) &
PID1=$!
(PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node2 -p 5432 -U aplicacion clusterdb) &
PID2=$!
(PGPASSWORD=$NODE_PASSWORD pgbench -S -c $CLIENTES -j 4 -T $DURATION -h node3 -p 5432 -U aplicacion clusterdb) &
PID3=$!
wait $PID1 $PID2 $PID3
echo "Tres nodos listo"
