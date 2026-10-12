import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pedidos_list_screen.dart';

const List<String> kMetodosPago = ['efectivo', 'tarjeta', 'app'];

class CrearPedidoScreen extends StatefulWidget {
  const CrearPedidoScreen({super.key});

  @override
  State<CrearPedidoScreen> createState() => _CrearPedidoScreenState();
}

class _CrearPedidoScreenState extends State<CrearPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  final _clienteCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _zona;
  String? _metodoPago;

  bool _enviando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _errorGeneral = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await _api.crearPedido(
        cliente: _clienteCtrl.text.trim(),
        zona: _zona!,
        metodoPago: _metodoPago!,
        monto: double.parse(_montoCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido creado correctamente.')),
        );
        Navigator.pop(context, true); // true = hubo cambios, refrescar lista
      }
    } on ApiException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo pedido')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_errorGeneral != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(_errorGeneral!, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _clienteCtrl,
                decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El cliente es requerido.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Zona', border: OutlineInputBorder()),
                value: _zona,
                items: kZonas.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                onChanged: (v) => setState(() => _zona = v),
                validator: (v) => v == null ? 'Selecciona una zona.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Método de pago', border: OutlineInputBorder()),
                value: _metodoPago,
                items: kMetodosPago.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _metodoPago = v),
                validator: (v) => v == null ? 'Selecciona un método de pago.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoCtrl,
                decoration: const InputDecoration(labelText: 'Monto (COP)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El monto es requerido.';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Ingresa un monto numérico mayor a 0.';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _guardar,
                  child: _enviando
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Crear pedido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
