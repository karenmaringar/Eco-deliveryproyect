import 'package:flutter/material.dart';

/// Chip visual que muestra el estado de un pedido con un color asociado,
/// para que el equipo de operaciones lo identifique de un vistazo.
class EstadoChip extends StatelessWidget {
  final String estado;

  const EstadoChip({super.key, required this.estado});

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'en_camino':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _textoLegible(String estado) {
    switch (estado) {
      case 'en_camino':
        return 'En camino';
      default:
        return estado[0].toUpperCase() + estado.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorPorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        _textoLegible(estado),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
