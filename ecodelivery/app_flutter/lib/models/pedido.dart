/// Modelo de datos que representa un Pedido, tal como lo devuelve la API
/// del backend (GET /pedidos, GET /pedidos/:id).
class Pedido {
  final int idPedido;
  final String cliente;
  final String zona;
  final DateTime fechaCreacion;
  final DateTime? fechaEntrega;
  final String estado; // pendiente | en_camino | entregado | cancelado
  final String? repartidor;
  final String metodoPago; // efectivo | tarjeta | app
  final double monto;

  Pedido({
    required this.idPedido,
    required this.cliente,
    required this.zona,
    required this.fechaCreacion,
    this.fechaEntrega,
    required this.estado,
    this.repartidor,
    required this.metodoPago,
    required this.monto,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      idPedido: json['id_pedido'] is int
          ? json['id_pedido']
          : int.parse(json['id_pedido'].toString()),
      cliente: json['cliente'] ?? '',
      zona: json['zona'] ?? '',
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      fechaEntrega: json['fecha_entrega'] != null
          ? DateTime.tryParse(json['fecha_entrega'])
          : null,
      estado: json['estado'] ?? 'pendiente',
      repartidor: json['repartidor'],
      metodoPago: json['metodo_pago'] ?? '',
      monto: (json['monto'] as num).toDouble(),
    );
  }

  /// Siguiente estado lógico en el flujo del pedido, o null si es un
  /// estado final (entregado / cancelado) y no se puede avanzar más.
  String? get siguienteEstado {
    switch (estado) {
      case 'pendiente':
        return 'en_camino';
      case 'en_camino':
        return 'entregado';
      default:
        return null;
    }
  }
}
