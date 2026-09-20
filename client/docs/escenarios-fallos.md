Pruebas de operatividad — Escenarios de falla

**Fecha de ejecución:** [completar]
**Nodos del clúster:** db-node1 (primario), db-node2 (secundario), db-node3 (secundario)
**Cliente usado:** cluster-client (Node.js), apuntando a [host/puerto del proxy]

---

Escenario A — Todos los nodos activos

**Comando ejecutado:** (ninguno, estado base)

| Métrica | Valor observado |
|---|---|
| Tiempo de respuesta promedio | |
| TPS/QPS | |
| Latencia | |
| CPU (por nodo) | |
| RAM (por nodo) | |
| I/O | |

**Observaciones del cliente (resultados.csv):**
- Estado: [OK / FALLO]
- Nodo que atendió las consultas:

---

Escenario B — Nodo secundario fuera de servicio

**Comando ejecutado:**
```bash
docker stop db-node3
```

**Hora exacta del comando:** [completar]

| Pregunta | Respuesta |
|---|---|
| ¿El sistema sigue funcionando? | |
| ¿Se pierden consultas? | |
| ¿Aumenta la latencia? | |
| ¿Qué nodo absorbe la carga? | |
| ¿Existe degradación del servicio? | |

**Evidencia del cliente:** (pegar líneas relevantes de resultados.csv, timestamp del primer FALLO si lo hay)

---

Escenario C — Recuperación del nodo

**Comando ejecutado:**
```bash
docker start db-node3
```

**Hora exacta del comando:** [completar]

| Métrica | Valor observado |
|---|---|
| Tiempo de recuperación (desde el `start` hasta que vuelve a responder) | |
| ¿Hubo resincronización visible? | |
| Estado de los datos post-recuperación | |
| Impacto sobre el rendimiento durante la resincronización | |

**Evidencia del cliente:** (timestamp del primer OK después del start)

---

Escenario D — Fallo del nodo primario

**Comando ejecutado:**
```bash
docker stop db-node1
```

**Hora exacta del comando:** [completar]

| Pregunta | Respuesta |
|---|---|
| ¿Existe failover automático? | |
| ¿Quién asume el rol de primario? | |
| ¿Cuánto demora el failover? | |
| ¿El cliente pierde conexión? | |
| ¿Se producen errores? (pegar mensaje exacto) | |
| ¿Existe pérdida de datos? | |

**Evidencia del cliente:** (secuencia completa de FALLO hasta que vuelve a loguear OK, si es que vuelve)

---

Conclusión general

[Resumen de qué tan resiliente resultó la arquitectura elegida, comparando los 4 escenarios]