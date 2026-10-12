import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido.dart';

/// Excepción específica para errores de la API, con el mensaje ya
/// listo para mostrar al usuario.
class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);
  @override
  String toString() => mensaje;
}

class ApiService {
  /// Base URL del backend.
  /// - Emulador Android: usar 10.0.2.2 en lugar de localhost.
  /// - Dispositivo físico / web: usar la IP de la máquina donde corre el backend.
  /// - iOS simulator: localhost funciona directamente.
  static const String baseUrl = 'http://localhost:3000';

  /// Si el backend exige API key (ver backend/.env.example), colócala aquí.
  static const String? apiKey = null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null) 'x-api-key': apiKey!,
      };

  /// GET /pedidos con filtros opcionales por estado y/o zona.
  Future<List<Pedido>> listarPedidos({String? estado, String? zona}) async {
    final params = <String, String>{};
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;
    if (zona != null && zona.isNotEmpty) params['zona'] = zona;

    final uri = Uri.parse('$baseUrl/pedidos').replace(queryParameters: params.isEmpty ? null : params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Pedido.fromJson(e)).toList();
      }
      throw ApiException('Error del servidor (${response.statusCode}) al listar pedidos.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor. Verifica tu conexión.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ocurrió un error inesperado: $e');
    }
  }

  /// GET /pedidos/:id
  Future<Pedido> obtenerPedido(int id) async {
    final uri = Uri.parse('$baseUrl/pedidos/$id');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return Pedido.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw ApiException('El pedido no existe.');
      }
      throw ApiException('Error del servidor (${response.statusCode}).');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ocurrió un error inesperado: $e');
    }
  }

  /// POST /pedidos
  Future<Pedido> crearPedido({
    required String cliente,
    required String zona,
    required String metodoPago,
    required double monto,
  }) async {
    final uri = Uri.parse('$baseUrl/pedidos');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'cliente': cliente,
              'zona': zona,
              'metodo_pago': metodoPago,
              'monto': monto,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return Pedido.fromJson(jsonDecode(response.body));
      }

      final body = jsonDecode(response.body);
      final detalles = (body['detalles'] as List?)?.join(', ') ?? 'Error al crear el pedido.';
      throw ApiException(detalles);
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ocurrió un error inesperado: $e');
    }
  }

  /// PATCH /pedidos/:id/estado
  Future<Pedido> actualizarEstado(int id, String nuevoEstado) async {
    final uri = Uri.parse('$baseUrl/pedidos/$id/estado');
    try {
      final response = await http
          .patch(
            uri,
            headers: _headers,
            body: jsonEncode({'estado': nuevoEstado}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Pedido.fromJson(jsonDecode(response.body));
      }

      final body = jsonDecode(response.body);
      final detalles = (body['detalles'] as List?)?.join(', ') ?? 'No se pudo actualizar el estado.';
      throw ApiException(detalles);
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ocurrió un error inesperado: $e');
    }
  }
}
