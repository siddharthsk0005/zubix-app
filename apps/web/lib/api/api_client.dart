import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// JSON client for the Zubix API. Errors follow `{ "error": { "code", "message" } }`.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<Map<String, dynamic>> post(String path, {Object? body, String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> patch(String path, {Object? body, String? token}) =>
      _send('PATCH', path, body: body, token: token);

  Future<Map<String, dynamic>> put(String path, {Object? body, String? token}) =>
      _send('PUT', path, body: body, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } catch (_) {
      throw ApiException('NETWORK_ERROR', 'Could not reach the Zubix API. Is the backend running?');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(
        error?['code'] as String? ?? 'HTTP_${response.statusCode}',
        error?['message'] as String? ?? 'Something went wrong. Please try again.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void close() => _http.close();
}
