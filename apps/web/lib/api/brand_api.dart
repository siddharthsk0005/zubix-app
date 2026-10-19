import 'api_client.dart';

/// Brand partner endpoints. Register, login and categories are public; the rest need the brand token.
class BrandApi {
  BrandApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> register(Map<String, Object?> body) =>
      _client.post('/brands/auth/register', body: body);

  Future<Map<String, dynamic>> login(String email, String password) =>
      _client.post('/brands/auth/login', body: {'email': email, 'password': password});

  Future<List<Map<String, dynamic>>> categories() async {
    final json = await _client.get('/categories');
    return (json['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> me(String token) async =>
      (await _client.get('/brands/me', token: token))['brand'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProfile(String token, Map<String, Object?> body) async =>
      (await _client.patch('/brands/me', token: token, body: body))['brand'] as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> sessions(String token) async {
    final json = await _client.get('/brands/me/sessions', token: token);
    return (json['sessions'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> requestSession(String token, Map<String, Object?> body) async =>
      (await _client.post('/brands/me/sessions', token: token, body: body))['session'] as Map<String, dynamic>;

  Future<void> cancelSession(String token, String id) =>
      _client.post('/brands/me/sessions/$id/cancel', token: token);
}
