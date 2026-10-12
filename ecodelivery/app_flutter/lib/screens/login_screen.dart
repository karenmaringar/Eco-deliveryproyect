import 'package:flutter/material.dart';
import 'pedidos_list_screen.dart';

/// Login simple (requisito EXTRA, no bloqueante).
/// No valida contra un backend de autenticación real: es una pantalla
/// de entrada que simula la sesión de un usuario (cliente/repartidor)
/// antes de acceder al listado de pedidos.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 64, color: Colors.green),
                const SizedBox(height: 8),
                const Text('EcoDelivery', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text('Domicilios ecológicos', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usuarioCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa un usuario.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _claveCtrl,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa una contraseña.' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const PedidosListScreen()),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Ingresar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
