import 'dart:convert';

import 'package:http/http.dart' as http;

/// Product lookup by barcode via Open Food Facts (ODbL / DbCL, images CC BY-SA).
/// Single product reads only (limit: 15 requests/min per IP) — no search-as-you-type.
class OffProduct {
  const OffProduct({required this.code, this.name, this.plName, this.brand, this.quantity, this.imageUrl});

  final String code;
  final String? name; // best generic name
  final String? plName; // Polish name if present
  final String? brand;
  final String? quantity;
  final String? imageUrl;
}

enum OffResult { found, notFound, offline }

class OffService {
  static const _ua = 'Zlotika/0.1 (Flutter; zlotika.app)';

  static Future<(OffResult, OffProduct?)> lookup(String code, {http.Client? client}) async {
    final c = client ?? http.Client();
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json'
        '?fields=code,product_name,product_name_pl,product_name_lt,product_name_en,brands,quantity,image_front_small_url');
    try {
      final res = await c.get(uri, headers: {'User-Agent': _ua, 'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
      if (res.statusCode == 404) return (OffResult.notFound, null);
      if (res.statusCode != 200) return (OffResult.offline, null);
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['status'] != 1) return (OffResult.notFound, null);
      final p = j['product'] as Map<String, dynamic>;
      String? s(String k) {
        final v = (p[k] as String?)?.trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      return (
        OffResult.found,
        OffProduct(
          code: code,
          name: s('product_name_lt') ?? s('product_name_en') ?? s('product_name'),
          plName: s('product_name_pl'),
          brand: s('brands')?.split(',').first.trim(),
          quantity: s('quantity'),
          imageUrl: s('image_front_small_url'),
        ),
      );
    } catch (_) {
      return (OffResult.offline, null);
    } finally {
      if (client == null) c.close();
    }
  }
}
