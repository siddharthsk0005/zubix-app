import 'api_client.dart';

/// Admin endpoints. Every call except login needs the admin session token.
class AdminApi {
  AdminApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> login(String email, String password) =>
      _client.post('/admin/auth/login', body: {'email': email, 'password': password});

  Future<List<Map<String, dynamic>>> listUsers(String token, {String? status}) =>
      _list('/admin/users', 'users', token, status);

  Future<void> reviewUser(String token, String id, {required bool approve, String? note}) =>
      _review('/admin/users/$id/review', token, approve, note);

  Future<List<Map<String, dynamic>>> listBrands(String token, {String? status}) =>
      _list('/admin/brands', 'brands', token, status);

  Future<void> reviewBrand(String token, String id, {required bool approve, String? note}) =>
      _review('/admin/brands/$id/review', token, approve, note);

  Future<List<Map<String, dynamic>>> listSessions(String token, {String? status}) =>
      _list('/admin/sessions', 'sessions', token, status);

  Future<void> reviewSession(String token, String id, {required bool approve, String? note}) =>
      _review('/admin/sessions/$id/review', token, approve, note);

  Future<List<Map<String, dynamic>>> listCategories(String token) =>
      _list('/admin/categories', 'categories', token, null);

  Future<void> createCategory(String token, String name) =>
      _client.post('/admin/categories', token: token, body: {'name': name});

  Future<void> updateCategory(String token, String id, {String? name, bool? isActive}) =>
      _client.patch(
        '/admin/categories/$id',
        token: token,
        body: {'name': ?name, 'isActive': ?isActive},
      );

  Future<void> reorderCategories(String token, List<String> ids) =>
      _client.put('/admin/categories/order', token: token, body: {'ids': ids});

  Future<void> _review(String path, String token, bool approve, String? note) =>
      _client.post(
        path,
        token: token,
        body: {'decision': approve ? 'APPROVE' : 'REJECT', 'note': ?note},
      );

  Future<List<Map<String, dynamic>>> _list(
    String path,
    String key,
    String token,
    String? status,
  ) async {
    final query = status == null ? '' : '?status=$status';
    final json = await _client.get('$path$query', token: token);
    return (json[key] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
