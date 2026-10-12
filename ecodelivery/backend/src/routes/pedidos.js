const express = require('express');
const router = express.Router();
const pedidoModel = require('../models/pedidoModel');
const { requireApiKey } = require('../middleware/auth');

// POST /pedidos  -> crear pedido (requiere API key)
router.post('/', requireApiKey, (req, res) => {
  const { cliente, zona, metodo_pago, monto, repartidor } = req.body;

  const errores = [];
  if (!cliente || typeof cliente !== 'string' || !cliente.trim()) {
    errores.push('cliente es requerido y debe ser texto.');
  }
  if (!zona || !pedidoModel.ZONAS_VALIDAS.includes(zona)) {
    errores.push(`zona es requerida y debe ser una de: ${pedidoModel.ZONAS_VALIDAS.join(', ')}.`);
  }
  if (!metodo_pago || !pedidoModel.METODOS_PAGO_VALIDOS.includes(metodo_pago)) {
    errores.push(`metodo_pago es requerido y debe ser uno de: ${pedidoModel.METODOS_PAGO_VALIDOS.join(', ')}.`);
  }
  if (monto === undefined || monto === null || isNaN(Number(monto)) || Number(monto) <= 0) {
    errores.push('monto es requerido y debe ser un número mayor a 0.');
  }

  if (errores.length > 0) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: errores });
  }

  const pedido = pedidoModel.crearPedido({ cliente, zona, metodo_pago, monto: Number(monto), repartidor });
  return res.status(201).json(pedido);
});

// GET /pedidos?estado=&zona=  -> listar con filtros opcionales
router.get('/', (req, res) => {
  const { estado, zona } = req.query;

  if (estado && !pedidoModel.ESTADOS_VALIDOS.includes(estado)) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: [`estado inválido. Válidos: ${pedidoModel.ESTADOS_VALIDOS.join(', ')}`] });
  }
  if (zona && !pedidoModel.ZONAS_VALIDAS.includes(zona)) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: [`zona inválida. Válidas: ${pedidoModel.ZONAS_VALIDAS.join(', ')}`] });
  }

  const pedidos = pedidoModel.listarPedidos({ estado, zona });
  return res.status(200).json(pedidos);
});

// GET /pedidos/:id -> detalle
router.get('/:id', (req, res) => {
  const id = Number(req.params.id);
  if (isNaN(id)) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: ['id debe ser numérico.'] });
  }

  const pedido = pedidoModel.obtenerPedidoPorId(id);
  if (!pedido) {
    return res.status(404).json({ error: 'NOT_FOUND', detalles: [`No existe un pedido con id ${id}.`] });
  }
  return res.status(200).json(pedido);
});

// PATCH /pedidos/:id/estado -> actualizar estado (requiere API key)
router.patch('/:id/estado', requireApiKey, (req, res) => {
  const id = Number(req.params.id);
  const { estado, repartidor } = req.body;

  if (isNaN(id)) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: ['id debe ser numérico.'] });
  }
  if (!estado || !pedidoModel.ESTADOS_VALIDOS.includes(estado)) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', detalles: [`estado es requerido y debe ser uno de: ${pedidoModel.ESTADOS_VALIDOS.join(', ')}`] });
  }

  const resultado = pedidoModel.actualizarEstado(id, estado, repartidor);

  if (resultado.error === 'NOT_FOUND') {
    return res.status(404).json({ error: 'NOT_FOUND', detalles: [`No existe un pedido con id ${id}.`] });
  }
  if (resultado.error === 'TRANSICION_INVALIDA') {
    return res.status(400).json({ error: 'TRANSICION_INVALIDA', detalles: [resultado.mensaje] });
  }

  return res.status(200).json(resultado.pedido);
});

module.exports = router;
