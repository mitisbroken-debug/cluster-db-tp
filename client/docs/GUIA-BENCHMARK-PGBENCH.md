# Guía de Benchmark con pgbench — Cluster PostgreSQL

## Contexto importante

El clúster tiene **3 nodos** (1 primario + 2 réplicas) en lugar de 4. Por eso la tabla de escalabilidad llega hasta 3 nodos, no 4. **La razón es arquitectónica**: las escrituras siempre van al primario único (para garantizar consistencia), así que agregar más nodos secundarios ayuda a escalar **lecturas** (SELECT), pero no escrituras. Eso es exactamente lo que pregunta la consigna: "¿agregar nodos realmente mejora el rendimiento?"

---

## Paso 1 — Inicializar los datos de prueba (una sola vez)

`pgbench` ya viene en la imagen `postgres:16`. Corre esto **una sola vez** contra el proxy (que dirige al primario):

**En Windows (PowerShell):**
```powershell
docker exec -it node1 bash -c "PGPASSWORD=$($env:NODE_PASSWORD) pgbench -i -s 10 -h proxy -p 5432 -U aplicacion clusterdb"
```

**O más directo:**
```powershell
docker exec -it node1 bash -c "PGPASSWORD=\$NODE_PASSWORD pgbench -i -s 10 -h proxy -p 5432 -U aplicacion clusterdb"
```

⚠️ **IMPORTANTE:** `pgbench` está **dentro del contenedor**, no en Windows. Siempre usar `docker exec`.

Esto crea las tablas estándar de pgbench (`pgbench_accounts`, etc.) con factor de escala 10 (~1 millón de filas). Suficiente para que las pruebas tengan volumen real.

---

## Paso 2 — Prueba de Concurrencia (5 niveles, 3 repeticiones cada uno)

### 2.1 El script

Crea el archivo `scripts/benchmark.sh` (o usa el que hay):

```bash
#!/bin/bash
set -e

HOST="proxy"
PORT="5432"
USER="aplicacion"
DB="clusterdb"
DURATION=30
REPETICIONES=3
NIVELES=(10 25 50 100 200)

OUTFILE="resultados_benchmark.csv"
echo "concurrencia,repeticion,tps,latencia_promedio_ms" > "$OUTFILE"

for c in "${NIVELES[@]}"; do
  for r in $(seq 1 $REPETICIONES); do
    echo "=== Concurrencia $c, repeticion $r ==="
    RESULTADO=$(PGPASSWORD=$NODE_PASSWORD pgbench -c "$c" -j 4 -T "$DURATION" -h "$HOST" -p "$PORT" -U "$USER" "$DB" 2>&1)
    echo "$RESULTADO"
    TPS=$(echo "$RESULTADO" | grep "tps = " | tail -1 | awk '{print $3}')
    LAT=$(echo "$RESULTADO" | grep "latency average" | awk '{print $4}')
    echo "$c,$r,$TPS,$LAT" >> "$OUTFILE"
  done
done

echo "Listo. Resultados en $OUTFILE"
```

**Qué hace cada parte:**
- `-c` = clientes concurrentes (5 niveles: 10, 25, 50, 100, 200)
- `-j 4` = 4 threads de pgbench (ajusta según los núcleos de tu PC)
- `-T 30` = cada corrida dura 30 segundos (comparable entre niveles)
- Repite cada nivel 3 veces, guarda todo en CSV

**Duración total:** 5 niveles × 3 repeticiones × 30 segundos = **~7.5 minutos**

### 2.2 Ejecutar

**Desde Windows (PowerShell):**

```powershell
# Copiar el script al contenedor
docker cp scripts/benchmark_concurrencia.sh node1:/tmp/benchmark_concurrencia.sh

# Ejecutarlo dentro del contenedor
docker exec -it node1 bash -c "chmod +x /tmp/benchmark_concurrencia.sh && /tmp/benchmark_concurrencia.sh"
```

El script se ejecuta **dentro de node1**, así tiene acceso a `pgbench` y a la variable de entorno `$NODE_PASSWORD`.

Mientras corre, va mostrando cada corrida en pantalla.

### 2.3 Traer los resultados

```powershell
docker cp node1:/tmp/resultados_benchmark.csv scripts/resultados_benchmark.csv
```

Abre el CSV en Excel/Calc y arma la tabla de concurrencia.

---

## Paso 3 — Tabla de Escalabilidad (1, 2, 3 nodos)

### 3.1 Script

Crea `scripts/benchmark-escalabilidad.sh`:

```bash
#!/bin/bash
set -e

DURATION=30
CLIENTES=50

mkdir -p /tmp/benchmark-results

echo "=== 1 nodo (solo node1, sin réplicas) ==="
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
```

**Nota:** `-S` = solo lecturas (SELECT). Eso es lo que sí se distribuye entre réplicas.

### 3.2 Ejecutar

**Desde Windows (PowerShell):**

```powershell
# Copiar el script al contenedor
docker cp scripts/benchmark_escalabilidad.sh node1:/tmp/benchmark_escalabilidad.sh

# Ejecutarlo dentro del contenedor
docker exec -it node1 bash -c "chmod +x /tmp/benchmark_escalabilidad.sh && /tmp/benchmark_escalabilidad.sh"
```

**Mientras corre cada nivel** (30 segundos por nodo), abre otra terminal y monitorea desde **Windows**:

```powershell
docker stats --no-stream
```

Anota CPU/RAM de cada contenedor en cada fase.

---

## Tabla de Escalabilidad (plantilla)

Completa esto con los datos que obtengas:

| Nodos leyendo | Clientes | TPS agregado | Latencia promedio (ms) | CPU (aprox) | RAM (aprox) |
|---|---|---|---|---|---|
| 1 | 50 | _____ | _____ | _____ | _____ |
| 2 | 50 | _____ | _____ | _____ | _____ |
| 3 | 50 | _____ | _____ | _____ | _____ |

**Qué esperar:**
- **TPS agregado** debería crecer casi linealmente con más nodos (porque crecen las lecturas)
- **Latencia** debería mantenerse relativamente estable
- **CPU/RAM** van a crecer un poco con más clientes concurrentes

---

## Para el informe

La consigna pregunta: *"¿Agregar nodos realmente mejora la performance? Explicar por qué sí o por qué no."*

**Respuesta justificada:**

> Sí, pero **solo para lecturas**. En este clúster de 3 nodos, el primario (node1) gestiona TODAS las escrituras. Las escrituras no se distribuyen (por diseño, para garantizar consistencia ACID). Los secundarios (node2, node3) sirven lecturas en paralelo.
>
> Cuando pasamos de 1 nodo a 2 a 3 nodos:
> - El TPS de **lecturas agregadas** crece (porque hay más réplicas sirviendo SELECT)
> - El TPS de **escrituras** NO cambia (solo node1 escribe, siempre)
> - La latencia de cada lectura individual puede mejorar o mantenerse (menos contención por cliente)
>
> Por eso la tabla de escalabilidad llega a 3 nodos, no 4. Agregar un cuarto nodo solo repetiría lo que ya hace node3 (servir lecturas). No hay beneficio real en rendimiento de escritura.

---

## Checklist

- [ ] Inicialicé datos con `pgbench -i`
- [ ] Creé y ejecuté el script de concurrencia
- [ ] Extracté el CSV de resultados
- [ ] Armé la tabla de concurrencia en el informe
- [ ] Creé y ejecuté el script de escalabilidad
- [ ] Anoté los datos de 1, 2, 3 nodos
- [ ] Monitoreé CPU/RAM con `docker stats`
- [ ] Justifiqué por qué no hay 4 nodos en la tabla
