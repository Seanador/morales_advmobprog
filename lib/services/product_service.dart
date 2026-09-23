import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/product_model.dart';

class ProductService {
  ProductService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<List<Product>> getAllProducts() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$host/products'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>;
        return products
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {
      // Keep the bundled catalogue available when the network is unavailable.
    } finally {
      if (_client == null) client.close();
    }
    final raw = await rootBundle.loadString('lib/services/products.json');
    final products = jsonDecode(raw) as List<dynamic>;
    return products
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
