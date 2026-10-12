// Carga el dataset_pedidos_semilla.csv (ubicado en la raíz del proyecto)
// dentro de la base de datos SQLite, para tener datos de prueba consistentes
// entre el backend, el pipeline de Airflow y el dashboard de Power BI.

const fs = require('fs');
const path = require('path');
const db = require('./connection');

const CSV_PATH = path.join(__dirname, '..', '..', '..', 'dataset_pedidos_semilla.csv');

// Parser simple de CSV (sin dependencias externas): nuestro dataset no tiene
// comas dentro de los campos, así que un split por línea/coma es suficiente.
function parseCSV(contenido) {
  const lineas = contenido.trim().split(/\r?\n/);
  const encabezados = lineas[0].split(',');
  return lineas.slice(1).map((linea) => {
    const valores = linea.split(',');
    const fila = {};
    encabezados.forEach((h, i) => { fila[h] = valores[i]; });
    return fila;
  });
}

function seed() {
  if (!fs.existsSync(CSV_PATH)) {
    console.error(`No se encontró el archivo semilla en: ${CSV_PATH}`);
    process.exit(1);
  }

  const contenido = fs.readFileSync(CSV_PATH, 'utf-8');
  const registros = parseCSV(contenido);

  db.exec('DELETE FROM pedidos;'); // idempotente: limpia antes de recargar

  const insertar = db.prepare(`
    INSERT INTO pedidos (id_pedido, cliente, zona, fecha_creacion, fecha_entrega, estado, repartidor, metodo_pago, monto)
    VALUES (@id_pedido, @cliente, @zona, @fecha_creacion, @fecha_entrega, @estado, @repartidor, @metodo_pago, @monto)
  `);

  db.exec('BEGIN TRANSACTION;');
  try {
    for (const fila of registros) {
      insertar.run({
        id_pedido: Number(fila.id_pedido),
        cliente: fila.cliente,
        zona: fila.zona,
        fecha_creacion: fila.fecha_creacion,
        fecha_entrega: fila.fecha_entrega || null,
        estado: fila.estado,
        repartidor: fila.repartidor || null,
        metodo_pago: fila.metodo_pago,
        monto: Number(fila.monto),
      });
    }
    db.exec('COMMIT;');
  } catch (err) {
    db.exec('ROLLBACK;');
    throw err;
  }

  console.log(`Se cargaron ${registros.length} pedidos desde el dataset semilla.`);
}

seed();
