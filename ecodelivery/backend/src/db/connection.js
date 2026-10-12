const path = require('path');
const { DatabaseSync } = require('node:sqlite'); // módulo nativo de Node (>= 22.5), sin compilación  'node:sqlite' con esto nso esta diceindo que estamos usando sqlite

const DB_PATH = path.join(__dirname, '..', '..', 'ecodelivery.db'); //esta es la base de datos ecodelivery .db
const db = new DatabaseSync(DB_PATH); //abre o crea una base de datos SQLITE en este archivo

db.exec('PRAGMA journal_mode = WAL;');
db.exec('PRAGMA foreign_keys = ON;');

// Creación del esquema si no existe (idempotente) // este crea una tabla si no existe, y la tabla se va a llamar pedidos
db.exec(`
  CREATE TABLE IF NOT EXISTS pedidos ( 
    id_pedido       INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente         TEXT NOT NULL,
    zona            TEXT NOT NULL CHECK (zona IN ('Norte','Sur','Centro','Occidente','Chapinero')),
    fecha_creacion  TEXT NOT NULL,
    fecha_entrega   TEXT,
    estado          TEXT NOT NULL CHECK (estado IN ('pendiente','en_camino','entregado','cancelado')) DEFAULT 'pendiente',
    repartidor      TEXT,
    metodo_pago     TEXT NOT NULL CHECK (metodo_pago IN ('efectivo','tarjeta','app')),
    monto           REAL NOT NULL CHECK (monto >= 0)
  );
`);

module.exports = db;
