// Autenticación simple por API Key (requisito EXTRA opcional del enunciado).
// Se protegen solo los endpoints de escritura (POST y PATCH).
// La API key se define en la variable de entorno API_KEY (ver .env.example).
// Si API_KEY no está configurada, el middleware se desactiva automáticamente
// (útil para pruebas rápidas en clase / sustentación).

const API_KEY = process.env.API_KEY || null;

function requireApiKey(req, res, next) {
  if (!API_KEY) {
    // Sin API_KEY configurada -> no se exige autenticación (modo demo)
    return next();
  }

  const key = req.header('x-api-key');
  if (!key || key !== API_KEY) {
    return res.status(401).json({ error: 'UNAUTHORIZED', detalles: ['Header x-api-key inválido o ausente.'] });
  }
  return next();
}

module.exports = { requireApiKey };
