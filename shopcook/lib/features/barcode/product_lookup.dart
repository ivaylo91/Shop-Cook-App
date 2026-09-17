import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers.dart';
import '../../data/local/database.dart';

/// Turns a scanned barcode into a product name.
///
/// Asks the phone first, then Open Food Facts: a free, open database with
/// no key, and decent coverage of Bulgarian shelves. Whatever the answer,
/// it is remembered, and so is a name the user types for a code nobody knew.
class ProductLookup {
  final AppDatabase _db;
  final http.Client _client;

  ProductLookup(this._db, this._client);

  static const _timeout = Duration(seconds: 8);

  Future<String?> nameFor(String code, {required String language}) async {
    final known = await _db.scannedProduct(code);
    if (known != null) return known.name;

    try {
      final response = await _client
          .get(
            Uri.https('world.openfoodfacts.org', '/api/v2/product/$code.json', {
              'fields':
                  'product_name,product_name_$language,generic_name,'
                  'generic_name_$language',
            }),
            // Open Food Facts asks every client to identify itself.
            headers: {'User-Agent': 'ShopCook/1.0 (Android; shopping list)'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['status'] != 1) return null;
      final product = data['product'];
      if (product is! Map) return null;

      final name = pickProductName(product, language);
      if (name != null) await _db.rememberBarcode(code, name);
      return name;
    } catch (_) {
      return null; // Offline, slow, or an odd reply: the user types it.
    }
  }

  /// Records what the user called a code the lookup did not know.
  Future<void> remember(String code, String name) =>
      _db.rememberBarcode(code, name.trim());
}

/// The best name in a product record: the app's language first, then the
/// product's own name, then its generic description.
String? pickProductName(Map<dynamic, dynamic> product, String language) {
  for (final key in [
    'product_name_$language',
    'product_name',
    'generic_name_$language',
    'generic_name',
  ]) {
    final value = product[key];
    if (value is String) {
      final name = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (name.isNotEmpty) return name;
    }
  }
  return null;
}

final productLookupProvider = Provider<ProductLookup>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ProductLookup(ref.watch(databaseProvider), client);
});
