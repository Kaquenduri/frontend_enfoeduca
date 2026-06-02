import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer ',
    };
  }

  /// NUEVO MÉTODO: Extrae el student_id decodificando el JWT almacenado
  static Future<String> getStudentId() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No se encontró una sesión activa (Token nulo).');
    }

    try {
      // Decodificamos el Payload del JWT en un mapa de Dart
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Extraemos el ID inyectado por tu backend mediante "...roleIdData"
      final studentId = decodedToken['student_id'];

      if (studentId == null) {
        throw Exception(
          'El usuario autenticado no cuenta con el rol o código de estudiante.',
        );
      }

      return studentId.toString();
    } catch (e) {
      throw Exception('Error al procesar las credenciales de la sesión: $e');
    }
  }

  // Generic GET request
  static Future<List<T>> getList<T>(
    String url,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data.map((object) => fromJson(object)).toList();
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Generic POST request
  static Future<dynamic> post(String url, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to post data to ');
    }
  }

  // Generic PUT request
  static Future<dynamic> put(String url, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to put data to ');
    }
  }

  // Generic DELETE request
  static Future<dynamic> delete(String url) async {
    final headers = await getHeaders();
    final response = await http.delete(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete data from ');
    }
  }
}
