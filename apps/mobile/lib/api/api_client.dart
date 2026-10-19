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

/// Thin JSON client for the Zubix API.
///
/// Expects errors in the shape `{ "error": { "code", "message" } }`.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      send('GET', path, token: token);

  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } catch (_) {
      throw ApiException('NETWORK_ERROR', 'Could not reach Zubix. Check your connection.');
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
