require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');

const config = {
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectionTimeoutMillis: 3000,
  max: 5,
};

const intervalMs = parseInt(process.env.QUERY_INTERVAL_MS, 10) || 2000;
const logFile = process.env.LOG_FILE || 'resultados.csv';

const pool = new Pool(config);

// Si el pool tira un error en una conexión ociosa, lo logueamos pero no tiramos el proceso abajo
pool.on('error', (err) => {
  logResult('ERROR_POOL', null, err.message);
});

// Si el archivo de log no existe, le ponemos encabezado
if (!fs.existsSync(logFile)) {
  fs.writeFileSync(logFile, 'timestamp,estado,latencia_ms,detalle\n');
}

function logResult(estado, latenciaMs, detalle) {
  const timestamp = new Date().toISOString();
  const linea = `${timestamp},${estado},${latenciaMs ?? ''},"${(detalle || '').replace(/"/g, "'")}"\n`;
  fs.appendFileSync(logFile, linea);
  console.log(`[${timestamp}] ${estado}${latenciaMs != null ? ` (${latenciaMs}ms)` : ''}${detalle ? ' - ' + detalle : ''}`);
}

async function probarConexion() {
  const inicio = Date.now();
  try {
    const res = await pool.query('SELECT NOW() AS hora, inet_server_addr() AS nodo');
    const latencia = Date.now() - inicio;
    const nodo = res.rows[0].nodo || 'desconocido';
    logResult('OK', latencia, `atendido por nodo ${nodo}`);
  } catch (err) {
    const latencia = Date.now() - inicio;
    logResult('FALLO', latencia, err.message);
  }
}

console.log(`Cliente iniciado. Conectando a ${config.host}:${config.port} cada ${intervalMs}ms`);
console.log(`Log en: ${logFile}`);
console.log('Presioná Ctrl+C para detener.\n');

// Primera prueba inmediata, después por intervalo
probarConexion();
const interval = setInterval(probarConexion, intervalMs);

// Cierre prolijo con Ctrl+C
process.on('SIGINT', async () => {
  console.log('\nCerrando cliente...');
  clearInterval(interval);
  await pool.end();
  process.exit(0);
});