import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Open Prices (Open Food Facts): an open database of prices that shoppers photograph
/// on shelf tags and receipts (ODbL). Zlotika users can contribute with their own
/// Open Food Facts account; the daily collector reads the prices back for everyone.
class OpenPrices {
  static const base = 'https://prices.openfoodfacts.org/api/v1';
  static const signUpUrl = 'https://world.openfoodfacts.org/cgi/user.pl';
  static const _tokenKey = 'openprices.token', _userKey = 'openprices.user';
  static const _store = FlutterSecureStorage();
  static const _ua = 'Zlotika (free open-source app; github.com/Zenkiux/zlotika)';

  static Future<String?> user() => _store.read(key: _userKey);
  static Future<String?> _token() => _store.read(key: _tokenKey);

  /// Signs in with an Open Food Facts user name (not e-mail) and password. Only the
  /// returned session token is kept (in the phone's keychain); the password is not stored.
  static Future<void> signIn(String user, String password, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c.post(Uri.parse('$base/auth'), headers: {'User-Agent': _ua}, body: {'username': user.trim(), 'password': password});
      if (r.statusCode == 401 || r.statusCode == 403) throw const OpenPricesError('auth');
      if (r.statusCode != 200) throw OpenPricesError('http ${r.statusCode}');
      final token = (jsonDecode(r.body) as Map<String, dynamic>)['access_token'] ?? (jsonDecode(r.body) as Map<String, dynamic>)['token'];
      if (token is! String || token.isEmpty) throw const OpenPricesError('no token');
      await _store.write(key: _tokenKey, value: token);
      await _store.write(key: _userKey, value: user.trim());
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<void> signOut() async {
    await _store.delete(key: _tokenKey);
    await _store.delete(key: _userKey);
  }

  /// Uploads the shelf-tag photo, then the price that points at it. Returns the price id.
  static Future<int> report({
    required File photo,
    required String barcode,
    required double price,
    required bool discounted,
    required int osmId,
    required String osmType, // NODE / WAY / RELATION
    required String date, // yyyy-mm-dd
    http.Client? client,
  }) async {
    final token = await _token();
    if (token == null) throw const OpenPricesError('auth');
    final c = client ?? http.Client();
    final auth = {'Authorization': 'Bearer $token', 'User-Agent': _ua};
    try {
      final up = http.MultipartRequest('POST', Uri.parse('$base/proofs/upload'))
        ..headers.addAll(auth)
        ..fields.addAll({'type': 'PRICE_TAG', 'currency': 'PLN', 'date': date, 'location_osm_id': '$osmId', 'location_osm_type': osmType})
        ..files.add(await http.MultipartFile.fromPath('file', photo.path));
      final ur = await http.Response.fromStream(await c.send(up));
      if (ur.statusCode == 401 || ur.statusCode == 403) throw const OpenPricesError('auth');
      if (ur.statusCode >= 300) throw OpenPricesError('proof ${ur.statusCode}');
      final proofId = (jsonDecode(ur.body) as Map<String, dynamic>)['id'] as int;
      final pr = await c.post(
        Uri.parse('$base/prices'),
        headers: {...auth, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'PRODUCT',
          'product_code': barcode,
          'price': price,
          'price_is_discounted': discounted,
          'currency': 'PLN',
          'date': date,
          'location_osm_id': osmId,
          'location_osm_type': osmType,
          'proof_id': proofId,
        }),
      );
      if (pr.statusCode >= 300) throw OpenPricesError('price ${pr.statusCode}: ${pr.body.length > 160 ? pr.body.substring(0, 160) : pr.body}');
      return (jsonDecode(pr.body) as Map<String, dynamic>)['id'] as int;
    } finally {
      if (client == null) c.close();
    }
  }

  /// "osm:w123" → (123, 'WAY'). Shops added from chain locators have no OSM id.
  static (int, String)? osmRef(String storeId) {
    final m = RegExp(r'^osm:([nwr])(\d+)$').firstMatch(storeId);
    if (m == null) return null;
    return (int.parse(m.group(2)!), const {'n': 'NODE', 'w': 'WAY', 'r': 'RELATION'}[m.group(1)]!);
  }
}

class OpenPricesError implements Exception {
  const OpenPricesError(this.code);
  final String code; // 'auth' = sign in again
  @override
  String toString() => 'OpenPricesError($code)';
}
