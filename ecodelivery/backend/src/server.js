const express = require('express');
const cors = require('cors');
const pedidosRouter = require('./routes/pedidos');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    servicio: 'EcoDelivery API',
    estado: 'ok',
    endpoints: [
      'POST /pedidos',
      'GET /pedidos',
      'GET /pedidos/:id',
      'PATCH /pedidos/:id/estado',
    ],
  });
});

app.use('/pedidos', pedidosRouter);

// Manejo de rutas no encontradas
app.use((req, res) => {
  res.status(404).json({ error: 'NOT_FOUND', detalles: ['Ruta no encontrada.'] });
});

// Manejo de errores no controlados
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'INTERNAL_ERROR', detalles: ['Ocurrió un error inesperado.'] });
});

app.listen(PORT, () => {
  console.log(`EcoDelivery API corriendo en http://localhost:${PORT}`);
});
