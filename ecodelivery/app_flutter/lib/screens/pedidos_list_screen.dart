import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/api_service.dart';
import '../widgets/estado_chip.dart';
import 'pedido_detail_screen.dart';
import 'crear_pedido_screen.dart';

const List<String> kZonas = ['Norte', 'Sur', 'Centro', 'Occidente', 'Chapinero'];
const List<String> kEstados = ['pendiente', 'en_camino', 'entregado', 'cancelado'];

class PedidosListScreen extends StatefulWidget {
  const PedidosListScreen({super.key});

  @override
  State<PedidosListScreen> createState() => _PedidosListScreenState();
}

class _PedidosListScreenState extends State<PedidosListScreen> {
  final ApiService _api = ApiService();

  late Future<List<Pedido>> _futurePedidos;
  String? _filtroEstado;
  String? _filtroZona;

  @override
  void initState() {
    super.initState();
    _futurePedidos = _api.listarPedidos();
  }

  void _recargar() {
    setState(() {
      _futurePedidos = _api.listarPedidos(estado: _filtroEstado, zona: _filtroZona);
    });
  }

  Future<void> _onPullToRefresh() async {
    final nuevos = _api.listarPedidos(estado: _filtroEstado, zona: _filtroZona);
    setState(() => _futurePedidos = nuevos);
    await nuevos; // esperamos a que termine para que el spinner de refresh no desaparezca antes de tiempo
  }

  final _formatoMoneda = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos EcoDelivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargar,
            tooltip: 'Recargar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CrearPedidoScreen()),
          );
          if (creado == true) _recargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido'),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: FutureBuilder<List<Pedido>>(
              future: _futurePedidos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }

                final pedidos = snapshot.data ?? [];
                if (pedidos.isEmpty) {
                  return const Center(child: Text('No hay pedidos con estos filtros.'));
                }

                return RefreshIndicator(
                  onRefresh: _onPullToRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: pedidos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = pedidos[index];
                      return ListTile(
                        title: Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.zona} · ${_formatoMoneda.format(p.monto)}'),
                        trailing: EstadoChip(estado: p.estado),
                        onTap: () async {
                          final cambio = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => PedidoDetailScreen(idPedido: p.idPedido)),
                          );
                          if (cambio == true) _recargar();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _recargar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Estado', isDense: true),
              value: _filtroEstado,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...kEstados.map((e) => DropdownMenuItem(value: e, child: Text(e))),
              ],
              onChanged: (v) {
                _filtroEstado = v;
                _recargar();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Zona', isDense: true),
              value: _filtroZona,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...kZonas.map((z) => DropdownMenuItem(value: z, child: Text(z))),
              ],
              onChanged: (v) {
                _filtroZona = v;
                _recargar();
              },
            ),
          ),
        ],
      ),
    );
  }
}
