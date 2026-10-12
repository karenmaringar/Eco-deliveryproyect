const db = require('../db/connection');

const ZONAS_VALIDAS = ['Norte', 'Sur', 'Centro', 'Occidente', 'Chapinero'];
const METODOS_PAGO_VALIDOS = ['efectivo', 'tarjeta', 'app'];
const ESTADOS_VALIDOS = ['pendiente', 'en_camino', 'entregado', 'cancelado'];

// Máquina de estados: qué transiciones son válidas desde cada estado.
// Regla de negocio: un pedido cancelado o entregado es un estado final (no se puede mover más).
const TRANSICIONES_VALIDAS = {
  pendiente: ['en_camino', 'cancelado'],
  en_camino: ['entregado', 'cancelado'],
  entregado: [],
  cancelado: [],
};

function crearPedido({ cliente, zona, metodo_pago, monto, repartidor }) {
  const fecha_creacion = new Date().toISOString();
  const stmt = db.prepare(`
    INSERT INTO pedidos (cliente, zona, fecha_creacion, estado, repartidor, metodo_pago, monto)
    VALUES (?, ?, ?, 'pendiente', ?, ?, ?)
  `);
  const info = stmt.run(cliente, zona, fecha_creacion, repartidor || null, metodo_pago, monto);
  return obtenerPedidoPorId(info.lastInsertRowid);
}

function listarPedidos({ estado, zona }) {
  let query = 'SELECT * FROM pedidos WHERE 1=1';
  const params = [];

  if (estado) {
    query += ' AND estado = ?';
    params.push(estado);
  }
  if (zona) {
    query += ' AND zona = ?';
    params.push(zona);
  }
  query += ' ORDER BY fecha_creacion DESC';

  return db.prepare(query).all(...params);
}

function obtenerPedidoPorId(id) {
  return db.prepare('SELECT * FROM pedidos WHERE id_pedido = ?').get(id);
}

function actualizarEstado(id, nuevoEstado, repartidor) {
  const pedido = obtenerPedidoPorId(id);
  if (!pedido) {
    return { error: 'NOT_FOUND' };
  }

  const permitidos = TRANSICIONES_VALIDAS[pedido.estado] || [];
  if (!permitidos.includes(nuevoEstado)) {
    return {
      error: 'TRANSICION_INVALIDA',
      mensaje: `No se puede pasar de '${pedido.estado}' a '${nuevoEstado}'. Transiciones válidas desde '${pedido.estado}': [${permitidos.join(', ') || 'ninguna'}]`,
    };
  }

  const fecha_entrega = nuevoEstado === 'entregado' ? new Date().toISOString() : pedido.fecha_entrega;
  const nuevoRepartidor = repartidor !== undefined ? repartidor : pedido.repartidor;

  db.prepare(`
    UPDATE pedidos
    SET estado = ?, fecha_entrega = ?, repartidor = ?
    WHERE id_pedido = ?
  `).run(nuevoEstado, fecha_entrega, nuevoRepartidor, id);

  return { pedido: obtenerPedidoPorId(id) };
}

module.exports = {
  crearPedido,
  listarPedidos,
  obtenerPedidoPorId,
  actualizarEstado,
  ZONAS_VALIDAS,
  METODOS_PAGO_VALIDOS,
  ESTADOS_VALIDOS,
  TRANSICIONES_VALIDAS,
};
