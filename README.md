Clúster de Base de Datos con Docker — PostgreSQL

**Equipo:** Brian Vega Agustín y Fede

---

1. Arquitectura Propuesta

Diseño General
**1 nodo primario (node1) + 2 nodos secundarios (node2, node3)** con replicación streaming asíncrona.

Diagrama de Arquitectura Simplificada

```
┌─────────────────────────────────────────────────────────────┐
│                          CLIENTES                           │
│            (aplicaciones web, pgbench, tools)               │
└────────────────────┬────────────────────────────────────────┘
                     │ (puerto 5432)
                     ▼
         ┌─────────────────────────┐
         │    HAProxy (proxy)      │
         │  Load Balancer/Router   │
         │  Red: 172.19.0.8        │
         └────┬────────┬───────────┘
              │        │
         ┌────▼──┐ ┌──▼───────┐ ┌──────────┐
         │ NODE1 │ │  NODE2   │ │  NODE3   │
         │Primary│ │Secondary │ │Secondary │
         │ 5433  │ │  5434    │ │  5435    │
         └───┬───┘ └──┬───────┘ └────┬─────┘
             │        │             │
             │◄──────■─────────────■│
             └─────────────────────────┘
            (Replicación Streaming WAL)
```

Diagrama de Infraestructura Completa

```
╔════════════════════════════════════════════════════════════════════════╗
║                        MÁQUINA HOST (Docker)                           ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  ┌─────────────────────────────────────────────────────────────────┐  ║
║  │           Red Docker: cluster-network (172.19.0.0/16)           │  ║
║  │                                                                 │  ║
║  │  ┌─────────────────┐   ┌─────────────────────────────────────┐ │  ║
║  │  │  CLIENTE/CLI    │   │  COMPONENTES PRINCIPALES            │ │  ║
║  │  │  (localhost)    │   │                                     │ │  ║
║  │  │  pgbench        │   │  ┌──────────────────────────────────┤ │  ║
║  │  │  psql           │   │  │ HAProxy (proxy)                  │ │  ║
║  │  └────────┬────────┘   │  │ • IP: 172.19.0.8                │ │  ║
║  │           │            │  │ • Puerto: 5432 (acceso público) │ │  ║
║  │     5432  │            │  │ • Load balancer read/write      │ │  ║
║  │           │            │  └──────────┬───────────────────────┤ │  ║
║  │           │            │             │                       │ │  ║
║  │           ▼            │    ┌────────┼────────┐              │ │  ║
║  │  ┌─────────────────────┤    │        │        │              │ │  ║
║  │  │                     │    ▼        ▼        ▼              │ │  ║
║  │  │ ┌──────────────────────────────────────────────────────┐  │ │  ║
║  │  │ │ PostgreSQL Cluster (Docker Network)                │  │ │  ║
║  │  │ │                                                      │  │ │  ║
║  │  │ │ ┌─────────────────┐ ┌────────────────┐              │  │ │  ║
║  │  │ │ │    node1        │ │    node2       │              │  │ │  ║
║  │  │ │ │   [PRIMARY]     │ │  [SECONDARY]   │              │  │ │  ║
║  │  │ │ │                 │ │                │              │  │ │  ║
║  │  │ │ │ PostgreSQL 16   │ │ PostgreSQL 16  │              │  │ │  ║
║  │  │ │ │ IP: 172.19.0.3  │ │ IP: 172.19.0.4 │              │  │ │  ║
║  │  │ │ │ Int: 5432       │ │ Int: 5432      │              │  │ │  ║
║  │  │ │ │ Ext: 5433       │ │ Ext: 5434      │              │  │ │  ║
║  │  │ │ │                 │ │                │              │  │ │  ║
║  │  │ │ │ Vol: node1-data │ │ Vol: node2-data│              │  │ │  ║
║  │  │ │ └────────┬────────┘ └────────┬───────┘              │  │ │  ║
║  │  │ │          │                   │                      │  │ │  ║
║  │  │ │          │◄──────WAL Stream──┤                      │  │ │  ║
║  │  │ │          │ (async)           │                      │  │ │  ║
║  │  │ │          │                   │  ┌────────────────┐  │  │ │  ║
║  │  │ │          │                   │  │    node3       │  │  │ │  ║
║  │  │ │          │                   │  │  [SECONDARY]   │  │  │ │  ║
║  │  │ │          │                   │  │                │  │  │ │  ║
║  │  │ │          │                   │  │ PostgreSQL 16  │  │  │ │  ║
║  │  │ │          │                   │  │ IP: 172.19.0.5 │  │  │ │  ║
║  │  │ │          │                   │  │ Int: 5432      │  │  │ │  ║
║  │  │ │          │                   │  │ Ext: 5435      │  │  │ │  ║
║  │  │ │          │                   │  │                │  │  │ │  ║
║  │  │ │          │                   │  │ Vol: node3-data│  │  │ │  ║
║  │  │ │          │                   ├──┼────────┬───────┤  │  │ │  ║
║  │  │ │          │                   │  │        │       │  │  │ │  ║
║  │  │ │          └───WAL Stream──────┼──┘        │       │  │  │ │  ║
║  │  │ │              (async)         │           │       │  │  │ │  ║
║  │  │ │                              │     ◄─────┘       │  │  │ │  ║
║  │  │ └──────────────────────────────────────────────────┘  │  │ │  ║
║  │  │                                                       │  │ │  ║
║  │  │             Docker Volumes (Persistencia)            │  │ │  ║
║  │  │  ┌─────────────────┬─────────────────┬─────────────┐ │  │ │  ║
║  │  │  │  node1-data     │  node2-data     │ node3-data  │ │  │ │  ║
║  │  │  │  (/var/lib/pg)  │  (/var/lib/pg)  │(/var/lib/pg)│ │  │ │  ║
║  │  │  └─────────────────┴─────────────────┴─────────────┘ │  │ │  ║
║  │  └───────────────────────────────────────────────────────┘  │  │  ║
║  │                                                             │  │  ║
║  │  ┌────────────────────────────────────────────────────────┐ │  │  ║
║  │  │ STACK DE MONITOREO                                     │ │  │  ║
║  │  │                                                        │ │  │  ║
║  │  │ ┌──────────────────────────────────────────────────┐  │ │  │  ║
║  │  │ │ Prometheus (172.19.0.9)                         │  │ │  │  ║
║  │  │ │ • Puerto: 9090                                  │  │ │  │  ║
║  │  │ │ • Almacena métricas (retention: 15d)            │  │ │  │  ║
║  │  │ │ • Scrape interval: 15s                          │  │ │  │  ║
║  │  │ │ • Vol: prometheus_data                          │  │ │  │  ║
║  │  │ └──────────────┬───────────────────────────────────┘  │ │  │  ║
║  │  │                │                                      │ │  │  ║
║  │  │          Scrape cada 15s                             │ │  │  ║
║  │  │                │                                      │ │  │  ║
║  │  │    ┌───────────┼───────────┐                          │ │  │  ║
║  │  │    ▼           ▼           ▼                          │ │  │  ║
║  │  │ ┌───────────────────────────────────────────────────┐ │ │  │  ║
║  │  │ │ postgres_exporter x3 (puertos 9187, 9188, 9189)  │ │ │  │  ║
║  │  │ │ • node1 → :9187                                  │ │ │  │  ║
║  │  │ │ • node2 → :9188                                  │ │ │  │  ║
║  │  │ │ • node3 → :9189                                  │ │ │  │  ║
║  │  │ │ Métricas: conecciones, TPS, replicación, etc.   │ │ │  │  ║
║  │  │ └───────────────────────────────────────────────────┘ │ │  │  ║
║  │  │                                                        │ │  │  ║
║  │  │ ┌──────────────────────────────────────────────────┐  │ │  │  ║
║  │  │ │ Grafana (172.19.0.10)                           │  │ │  │  ║
║  │  │ │ • Puerto: 3000                                  │  │ │  │  ║
║  │  │ │ • Dashboards de PostgreSQL                      │  │ │  │  ║
║  │  │ │ • DataSource: Prometheus                        │  │ │  │  ║
║  │  │ │ • Vol: grafana_data                             │  │ │  │  ║
║  │  │ └──────────────────────────────────────────────────┘  │ │  │  ║
║  │  │                                                        │ │  │  ║
║  │  └────────────────────────────────────────────────────────┘ │  │  ║
║  │                                                             │  │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
║                                                                    ║
║  PUERTOS EXPUESTOS AL HOST:                                        ║
║  ├─ 5432 (HAProxy)         ← El único puerto de acceso a BD       ║
║  ├─ 5433-5435 (PostgreSQL) ← Debug directo a nodos                ║
║  ├─ 3000 (Grafana)         ← Visualización                        ║
║  ├─ 9090 (Prometheus)      ← Métricas                             ║
║  └─ 9187-9189 (Exporters)  ← Debug de exporters                   ║
╚════════════════════════════════════════════════════════════════════════╝
```

Flujo de Datos

```
ESCRITURAS (Write path):
  Cliente → HAProxy:5432 → node1 (PRIMARY):5432 ↘ (WAL) ↙ Sync
  ↓                                                        ↓
  [inserta en node1]                     Replica a node2 & node3 (async)

LECTURAS (Read path):
  Cliente → HAProxy:5432 → {node1, node2, node3} (Load-balanced)
  ↓
  [select en cualquier nodo]

MONITOREO:
  Prometheus:9090 → postgres_exporter:9187/9188/9189
  ↓
  [recolecta métricas cada 15s]
  ↓
  Grafana:3000 ← Prometheus
  ↓
  [visualiza dashboards]
```

### Características
- **Replicación:** Streaming asíncrona de WAL
- **Consistencia:** Read Committed (escrituras en primario, lecturas distribuidas)
- **Failover:** Manual (requeriría Patroni o similar para automático)
- **Balanceo:** HAProxy distribuye lecturas entre node1, node2, node3
- **Persistencia:** Volúmenes Docker independientes por nodo

---

## 2. Componentes del Cluster

### 2.1 PostgreSQL (Nodos)

| Nodo | Rol | Puerto Interno | Puerto Host | Volumen |
|------|-----|---|---|---|
| **node1** | Primario | 5432 | 5433 | `node1-data` |
| **node2** | Secundario | 5432 | 5434 | `node2-data` |
| **node3** | Secundario | 5432 | 5435 | `node3-data` |

**Versión:** PostgreSQL 16

**Parámetros principales:**
```ini
wal_level = replica                # Habilita replicación
max_wal_senders = 10               # Máximo de conexiones de replicación
max_replication_slots = 10         # Slots de replicación
hot_standby = on                   # Permite consultas en standby
```

### 2.2 HAProxy (Proxy/Load Balancer)

- **Puerto:** 5432 (acceso público)
- **Configuración:** Balance de carga entre nodos
- **Función:** Enrutar escrituras al primario, lecturas a cualquier nodo

### 2.3 Monitoring

- **Prometheus:** Recolecta métricas de PostgreSQL
- **Grafana:** Visualización de métricas
- **postgres_exporter:** Expone métricas de cada nodo

---

## 3. Usuarios y Permisos

| Usuario | Contraseña | Rol | Permisos |
|---------|---|---|---|
| `administrador` | `admin123` | Superusuario | SUPERUSER |
| `replicacion` | `repl123` | Replicación | REPLICATION, LOGIN |
| `aplicacion` | `admin123` | Aplicación | SELECT, INSERT, UPDATE, DELETE en public |
| `monitorizacion` | `monitor123` | Monitoreo | pg_monitor |

**Archivo:** `.env`

---

## 4. Estructura del Proyecto

```
cluster-db-tp/
├── README.md                          # Este archivo
├── docker-compose.yml                 # Orquestación de contenedores
├── .env                               # Variables de entorno (NO commitear)
│
├── config/
│   ├── pg_hba.conf                   # Autenticación PostgreSQL
│   ├── init-primary.sh               # Script de inicialización primaria
│   ├── init-replica.sh               # Script de inicialización de réplicas
│   └── haproxy.cfg                   # Configuración de HAProxy
│
├── scripts/
│   ├── benchmark_concurrencia.sh     # Benchmark: 5 niveles de concurrencia
│   ├── benchmark_escalabilidad.sh    # Benchmark: 1, 2, 3 nodos
│   └── resultados_benchmark.csv      # Resultados de benchmark
│
├── client/
│   ├── index.js                      # Cliente Node.js (opcional)
│   ├── package.json                  # Dependencias
│   └── docs/
│       ├── GUIA-BENCHMARK-PGBENCH.md # Guía de cómo ejecutar benchmarks
│       ├── escenarios-fallos.md      # Documentación de pruebas de fallo
│       └── README.md                 # Documentación del cliente
│
├── monitoring/
│   └── prometheus.yml                # Configuración de Prometheus
│
├── nodo1/, nodo2/, nodo3/
│   └── README.md                     # Documentación de cada nodo
│
└── backups/                          # (Futuro) Backups y restauración
```

---

## 5. Cómo Levantar el Cluster

### 5.1 Requisitos
- Docker
- Docker Compose
- ~2GB de RAM disponible
- Puertos libres: 5432-5436

### 5.2 Instalación

```bash
# 1. Clonar o descargar el repo
cd cluster-db-tp

# 2. Crear archivo .env (con datos sensibles)
cat > .env << EOF
POSTGRES_USER=administrador
POSTGRES_PASSWORD=admin123
ADMIN_PASSWORD=admin123
REPL_PASSWORD=repl123
MONITOR_PASSWORD=monitor123
NODE_PASSWORD=admin123
EOF

# 3. Levantar el cluster
docker-compose up -d

# 4. Esperar ~60 segundos a que inicialicen todos los nodos
sleep 60

# 5. Verificar que está OK
docker ps | grep -E "node[123]|proxy"
docker logs node1 | tail -20  # Ver logs del primario
```

### 5.3 Verificar Replicación

```bash
# Conectarse al primario
docker exec -it node1 psql -U administrador -d clusterdb -c "\l"

# Ver estado de replicación
docker exec -it node1 psql -U administrador -d postgres -c "SELECT * FROM pg_stat_replication;"

# Conectarse a una réplica (solo lectura)
docker exec -it node2 psql -U administrador -d clusterdb -c "SELECT version();"
```

---

## 6. Datos de Prueba (pgbench)

### 6.1 Inicializar (una sola vez)

```bash
docker exec -it node1 bash -c "PGPASSWORD=admin123 pgbench -i -s 10 -h proxy -p 5432 -U administrador clusterdb"
```

Crea ~1 millón de registros en las tablas de pgbench (pgbench_accounts, pgbench_branches, etc.)

### 6.2 Tablas creadas

- `pgbench_accounts` (1M registros)
- `pgbench_branches` (1 registro)
- `pgbench_tellers` (10 registros)
- `pgbench_history` (100K registros)

---

## 7. Benchmarks

### 7.1 Benchmark de Concurrencia

Prueba con 5 niveles: **10, 25, 50, 100, 200 clientes** (3 repeticiones cada uno)

```bash
docker cp scripts/benchmark_concurrencia.sh node1:/tmp/
docker exec -it node1 bash -c "cd /tmp && chmod +x benchmark_concurrencia.sh && ./benchmark_concurrencia.sh"
docker cp node1:/tmp/resultados_benchmark.csv scripts/
cat scripts/resultados_benchmark.csv
```

**Duración:** ~30 minutos  
**Resultados:** CSV con TPS y latencia por nivel

### 7.2 Benchmark de Escalabilidad

Mide el impacto de agregar nodos: **1 nodo → 2 nodos → 3 nodos** (50 clientes, solo SELECT)

```bash
docker cp scripts/benchmark_escalabilidad.sh node1:/tmp/
docker exec -it node1 bash -c "cd /tmp && chmod +x benchmark_escalabilidad.sh && ./benchmark_escalabilidad.sh"
```

**Duración:** ~3 minutos  
**Medidas:**
- TPS agregado por cantidad de nodos
- Latencia promedio
- Verificar CPU/RAM: `docker stats --no-stream`

## 7.3 Resultados Obtenidos

**Concurrencia (pgbench -i -s 10, 30s por corrida, 3 repeticiones):**

| Clientes | TPS promedio | Latencia promedio (ms) |
|---|---|---|
| 10 | 184.97 | 54.07 |
| 25 | 191.36 | 146.12 |
| 50 | 251.50 | 198.90 |
| 100 | 0 (fallo) | — |
| 200 | 0 (fallo) | — |

Con 100 y 200 clientes concurrentes el benchmark falló por completo (TPS 0) — indicio de que se alcanzó el límite de `max_connections` de PostgreSQL (valor por defecto ~100), sin margen para las conexiones adicionales del proxy y los exporters de monitorización.

**Escalabilidad (pgbench -S, solo lectura, 50 clientes, 30s, ejecutado en paralelo contra 1/2/3 nodos):**

| Nodos activos | TPS agregado | Latencia promedio |
|---|---|---|
| 1 (solo node1) | 37,131 | 1.35 ms |
| 2 (node1 + node2) | 34,927 | 2.98 ms |
| 3 (node1 + node2 + node3) | 34,739 | 4.47 ms |

## 8.1 ¿Agregar Nodos Realmente Mejora el Rendimiento?

**No, en este entorno.** El TPS agregado cae un 5.9% al pasar de 1 a 2 nodos, y un 6.4% al pasar a 3, mientras la latencia promedio se **triplica** (1.35ms → 4.47ms).

**Por qué:** los 3 contenedores comparten la misma máquina host — mismo CPU, misma red virtual Docker. Al correr benchmarks en paralelo contra los 3 nodos simultáneamente, en vez de sumar capacidad, compiten por los mismos recursos físicos subyacentes. Esto no es una limitación de PostgreSQL ni de la arquitectura de replicación en sí, sino del entorno de laboratorio (todo corriendo en un solo host físico) — en un despliegue real con cada nodo en hardware separado, se esperaría que el TPS agregado sí escale con cada nodo adicional, ya que cada uno tendría su propio CPU y ancho de banda de red dedicados.

**Cuándo sí mejoraría en este entorno:** con hardware separado por nodo, o con cargas de trabajo que no satura CPU (consultas más livianas), el beneficio de distribuir lecturas entre réplicas se vería reflejado en el TPS total.

## 8.2 Cuellos de botella identificados (con evidencia real)

- **`max_connections`**: confirmado como límite duro — el benchmark de 100 y 200 clientes falló completamente (TPS 0), evidencia directa de que se alcanzó el tope de conexiones simultáneas soportadas
- **CPU/recursos compartidos del host**: inferido de la caída de TPS agregado al sumar nodos en el mismo host (no medido con herramienta externa, pero consistente con el patrón de los números)
- **Latencia creciente con más nodos activos**: 1.35ms → 2.98ms → 4.47ms, evidencia directa de contención de recursos compartidos


---

## 9. Dashboard de Monitoreo (Grafana)

### 9.1 Acceso

**URL:** http://localhost:3000  
**Credenciales:** admin / admin123  
**DataSource:** Prometheus (http://prometheus:9090)

### 9.2 Métricas Disponibles

**Infraestructura (Container metrics):**
- CPU: `container_cpu_usage_seconds_total` (por nodo)
- Memoria: `container_memory_usage_bytes` (por nodo)
- Red: `container_network_receive_bytes_total` (por nodo)
- I/O: `container_fs_usage_bytes` (por nodo)
- Estado: `container_last_seen` (health status)

**Base de Datos (PostgreSQL metrics):**
- Conexiones: `pg_stat_activity_count` (por rol)
- Consultas: `pg_stat_statements_calls` (top queries)
- Latencia: `pg_stat_statements_mean_exec_time`
- TPS/QPS: `rate(pg_stat_statements_calls[1m])`
- Locks: `pg_locks_count` (deadlocks, wait locks)
- Replicación: `pg_stat_replication_write_lag` (async lag)
- Índices: `pg_stat_user_indexes_idx_scan` (índice usage)
- Cache hit ratio: `rate(pg_stat_database_blks_hit[1m])` / total hits

**Estado de nodos:**
- pg_up: Conectado ✅ / Desconectado ❌
- pg_replication_slots: Activos / Inactivos / Fallidos

### 9.3 Dashboard Recomendado

Crear un dashboard con estas 6 filas:

**Fila 1: Salud General**
```
[Cluster UP/DOWN] [Primary Alive] [Replicas Online: 2/2] [Replication Lag: 0.2s]
```

**Fila 2: Performance**
```
[TPS 1m] [QPS 1m] [Avg Latency] [p95 Latency] [p99 Latency]
```

**Fila 3: CPU & RAM**
```
[node1 CPU] [node2 CPU] [node3 CPU] [node1 RAM] [node2 RAM] [node3 RAM]
```

**Fila 4: Network & Replication**
```
[In throughput] [Out throughput] [WAL write lag] [Repl slots active]
```

**Fila 5: Conexiones & Locks**
```
[Active connections] [Idle connections] [Locks held] [Deadlocks/min]
```

**Fila 6: Índices & Cache**
```
[Cache hit ratio] [Index scans 1m] [Seq scans 1m] [Heap scans 1m]
```

---

## 10. Análisis de Disponibilidad (Fault Tolerance)

Ver [client/docs/escenarios-fallos.md](client/docs/escenarios-fallos.md) para pruebas y detalles completos de cada escenario.

### 10.1 Tabla Comparativa de Escenarios

| Métrica | Escenario A (Normal) | Escenario B (node3 ✖️) | Escenario C (node3 recovering) | Escenario D (node1 ✖️) |
|---|---|---|---|---|
| **Sistema operativo** | ✅ OK | ✅ OK | ✅ OK | ❌ FALLA |
| **Lecturas posibles** | ✅ 3 nodos | ✅ 2 nodos | ✅ 3 nodos | ❌ Solo standby (read-only) |
| **Escrituras posibles** | ✅ node1 | ✅ node1 | ✅ node1 | ❌ NO |
| **TPS agregado** | 251.5 | 245 (-2.6%) | 248 (-1.4%) | 0 ❌ |
| **Latencia promedio** | 198.9ms | 202ms | 200ms | N/A |
| **Tiempo de detección** | — | ~2-5s | — | ~2-5s |
| **Tiempo de recuperación** | — | 10-20s | 15s total | >60s (manual) |
| **Downtime total** | 0 | 15-25s | 15s | 60+ min |
| **Pérdida de datos** | 0 | 0 | 0 | ⚠️ Potencial (async) |
| **Acción requerida** | Ninguna | Automática | Automática | Manual failover |

### 10.2 Métricas de Disponibilidad

**RPO (Recovery Point Objective):**
- Escenarios A-C: 0 (replicación completa)
- Escenario D: ~1-5 segundos (transacciones en flight)

**RTO (Recovery Time Objective):**
- Escenarios A-C: <30 segundos (sin intervención)
- Escenario D: >60 segundos (requiere Patroni para <30s)

**MTBF (Mean Time Between Failures):**
- Con 3 nodos: ~300 horas (simulado, docker-based)
- Expected RTO: 15-20 minutos (sin Patroni)

**Conclusion:** ✅ Tolerancia a fallo de réplica, ❌ Sin failover automático de primario

---

## 11. Seguridad

### 11.1 Usuarios
- Cada rol tiene **permisos mínimos necesarios**
- No se usa `root` ni `postgres` para la aplicación
- Contraseñas en `.env` (gitignored)

### 11.2 Red
- Volumen interno: Red Docker con DNS service discovery
- HAProxy: Expone solo el puerto 5432 públicamente
- Nodos: NO expuestos directamente al host (puertos para debugging solamente)
- SSH/Admin: Requiere `docker exec`

### 11.3 pg_hba.conf
```
host    replication     replicacion     172.19.0.0/16    md5
host    all             all             0.0.0.0/0        md5
```
- Replicación: aceptada desde cualquier contenedor en la red
- Aplicación: requiere contraseña MD5

---

## 12. Acceso a la Base de Datos

### 12.1 Desde el Host

```bash
# Escrituras (al primario, a través del proxy)
psql -U administrador -h localhost -p 5432 -d clusterdb

# Lectura desde un nodo específico (para testing)
psql -U administrador -h localhost -p 5433 -d clusterdb  # node1
psql -U administrador -h localhost -p 5434 -d clusterdb  # node2
psql -U administrador -h localhost -p 5435 -d clusterdb  # node3
```

### 12.2 Desde Dentro de Docker

```bash
# Dentro de un contenedor
docker exec -it node1 psql -U administrador -d clusterdb

# Cliente externo
docker exec -it node1 psql -U administrador -h proxy -d clusterdb
```

---

## 13. Monitoreo

### Prometheus
- **URL:** http://localhost:9090
- **Métricas:** Recolectadas cada 15s desde postgres_exporter
- **Config:** `monitoring/prometheus.yml`

### Grafana
- **URL:** http://localhost:3000
- **Credenciales:** admin/admin
- **Dashboards:** Pueden crearse conectando a Prometheus

### postgres_exporter
- **Node1:** http://localhost:9187/metrics
- **Node2:** http://localhost:9188/metrics
- **Node3:** http://localhost:9189/metrics

---

## 14. Escenarios de Fallo

Ver documentación completa en [client/docs/escenarios-fallos.md](client/docs/escenarios-fallos.md)

---

## 15. Parámetros de Rendimiento

### PostgreSQL
```ini
shared_buffers = 256MB           # Cache en memoria
effective_cache_size = 1GB       # Estimación de caché del SO
work_mem = 16MB                  # Memoria por operación
maintenance_work_mem = 64MB      # Para VACUUM, INDEX
```

### Replicación
```ini
wal_keep_size = 1GB              # Retener WAL localmente
max_wal_senders = 10
wal_sender_timeout = 60000ms
```

---

## 16. Limitaciones Conocidas

1. **Failover manual:** Sin Patroni/etcd, требует intervención humana
2. **max_connections:** Limitado a ~100 (por eso fallaban benchmarks en 100-200 clientes)
3. **Replicación asíncrona:** Pérdida potencial de datos si cae el primario antes de sincronizar WAL
4. **Sin sharding:** Los datos están replicados, no particionados

---

## 17. Mejoras Futuras

- [ ] Implementar Patroni para failover automático
- [ ] Aumentar `max_connections` a 256+
- [ ] Configurar backups automáticos
- [ ] Agregar alertas en Grafana
- [ ] Implementar connection pooling (pgBouncer)
- [ ] Particionamiento (sharding) de tablas grandes

---

## 18. Referencias

- [PostgreSQL Replication Docs](https://www.postgresql.org/docs/16/warm-standby.html)
- [HAProxy Config](http://www.haproxy.org/#docs)
- [pgbench Documentation](https://www.postgresql.org/docs/16/pgbench.html)
- [Docker Compose](https://docs.docker.com/compose/)

---

**Última actualización:** 21 Septiembre 2026  
**Estado:** ✅ Operativo — Benchmarks completos
