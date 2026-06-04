import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'api_service.dart';

enum ServiceType {
  academic,
  users,
  auth,
}

class ApiClient {
  static String _getBaseUrl(ServiceType type) {
    switch (type) {
      case ServiceType.academic:
        return Environment.academicServiceUrl;
      case ServiceType.users:
        return Environment.usersServiceUrl;
      case ServiceType.auth:
        return Environment.authServiceUrl;
    }
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true, Map<String, String>? extraHeaders}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extraHeaders,
    };
    
    if (requireAuth) {
      final token = await ApiService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<http.Response> get(ServiceType service, String endpoint, {bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> post(ServiceType service, String endpoint, {dynamic body, bool requireAuth = true, Map<String, String>? extraHeaders}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth, extraHeaders: extraHeaders);
    return await http.post(url, headers: headers, body: body != null ? json.encode(body) : null);
  }

  static Future<http.Response> put(ServiceType service, String endpoint, {dynamic body, bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.put(url, headers: headers, body: body != null ? json.encode(body) : null);
  }

  static Future<http.Response> delete(ServiceType service, String endpoint, {bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.delete(url, headers: headers);
  }
}
