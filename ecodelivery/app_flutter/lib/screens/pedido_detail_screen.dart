import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/api_service.dart';
import '../widgets/estado_chip.dart';

class PedidoDetailScreen extends StatefulWidget {
  final int idPedido;
  const PedidoDetailScreen({super.key, required this.idPedido});

  @override
  State<PedidoDetailScreen> createState() => _PedidoDetailScreenState();
}

class _PedidoDetailScreenState extends State<PedidoDetailScreen> {
  final ApiService _api = ApiService();
  late Future<Pedido> _futurePedido;
  bool _actualizando = false;
  bool _huboCambios = false;

  final _formatoMoneda = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _futurePedido = _api.obtenerPedido(widget.idPedido);
    });
  }

  Future<void> _avanzarEstado(String estadoActual, String siguienteEstado) async {
    setState(() => _actualizando = true);
    try {
      await _api.actualizarEstado(widget.idPedido, siguienteEstado);
      _huboCambios = true;
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pedido actualizado a "$siguienteEstado".')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Pedido #${widget.idPedido}')),
        body: FutureBuilder<Pedido>(
          future: _futurePedido,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                ),
              );
            }

            final p = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.cliente, style: Theme.of(context).textTheme.headlineSmall),
                      EstadoChip(estado: p.estado),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _fila('Zona', p.zona),
                  _fila('Monto', _formatoMoneda.format(p.monto)),
                  _fila('Método de pago', p.metodoPago),
                  _fila('Repartidor', p.repartidor ?? 'Sin asignar'),
                  _fila('Fecha creación', _formatoFecha.format(p.fechaCreacion)),
                  _fila('Fecha entrega', p.fechaEntrega != null ? _formatoFecha.format(p.fechaEntrega!) : '—'),
                  const Spacer(),
                  if (p.siguienteEstado != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _actualizando ? null : () => _avanzarEstado(p.estado, p.siguienteEstado!),
                        icon: _actualizando
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward),
                        label: Text(_actualizando ? 'Actualizando...' : 'Marcar como "${p.siguienteEstado}"'),
                      ),
                    )
                  else
                    const Text('Este pedido ya está en un estado final.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(etiqueta, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
