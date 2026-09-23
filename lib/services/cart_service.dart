import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cart.dart';

const String _base = 'https://dummyjson.com';

class CartService {
  final http.Client? _client;
  final Duration requestTimeout;

  CartService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client;

  //Enhancement 3
  // DummyJSON simulates cart writes. Keep session edits separated by user.
  static final Map<int, List<CartProduct>> _localItemsByUser = {};
  static final Map<int, Map<int, int>> _localQuantityOverridesByUser = {};

  Future<http.Response> _get(String path) {
    final uri = Uri.parse('$_base$path');
    return (_client?.get(uri) ?? http.get(uri)).timeout(requestTimeout);
  }

  Future<List<Cart>> getAllCarts() async {
    final response = await _get('/carts');
    if (response.statusCode != 200) {
      throw Exception('Failed to load carts (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['carts'] as List? ?? [])
        .map((json) => Cart.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Cart> getCartById(int id) async {
    final response = await _get('/carts/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to load cart (${response.statusCode})');
    }
    return Cart.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  //Enhancement 3
  // The authenticated user's ID is the only source of cart ownership.
  Future<List<Cart>> getCartByUser(int userId) async {
    if (userId < 1) throw ArgumentError.value(userId, 'userId');
    final response = await _get('/carts/user/$userId');
    if (response.statusCode != 200) {
      throw Exception('Failed to load your cart (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final carts = (data['carts'] as List? ?? [])
        .map((json) => Cart.fromJson(json as Map<String, dynamic>))
        .where((cart) => cart.userId == userId)
        .toList();
    final cart = _cartWithLocalItems(
      userId,
      carts.expand((cart) => cart.products),
      // A combined/local cart has no single remote ID.
      cartId: carts.length == 1 ? carts.single.id : 0,
    );
    return cart.products.isEmpty ? [] : [cart];
  }

  Future<int> getProductQuantity({
    required int userId,
    required int productId,
  }) async {
    final carts = await getCartByUser(userId);
    for (final cart in carts) {
      for (final product in cart.products) {
        if (product.id == productId) return product.quantity;
      }
    }
    return 0;
  }

  void addProductLocally({required int userId, required CartProduct product}) {
    if (product.quantity < 1) return;
    final localItems = _localItemsByUser.putIfAbsent(userId, () => []);
    final index = localItems.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      localItems.add(product);
    } else {
      final existing = localItems[index];
      localItems[index] = _copyWithQuantity(
        existing,
        existing.quantity + product.quantity,
      );
    }

    // A previous quantity edit is absolute; subsequent additions still count.
    final overrides = _localQuantityOverridesByUser[userId];
    final previousQuantity = overrides?[product.id];
    if (overrides != null && previousQuantity != null) {
      overrides[product.id] = previousQuantity + product.quantity;
    }
  }

  void updateProductQuantityLocally({
    required int userId,
    required int productId,
    required int quantity,
  }) {
    if (quantity < 1) return;
    final overrides = _localQuantityOverridesByUser.putIfAbsent(
      userId,
      () => {},
    );
    overrides[productId] = quantity;
  }

  Future<Cart> addToCart({
    required int userId,
    required List<CartProductInput> products,
  }) async {
    final uri = Uri.parse('$_base/carts/add');
    const headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'userId': userId,
      'products': products.map((product) => product.toJson()).toList(),
    });
    final response =
        await (_client?.post(uri, headers: headers, body: body) ??
                http.post(uri, headers: headers, body: body))
            .timeout(requestTimeout);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Cart.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to add to cart (${response.statusCode})');
  }

  Future<Cart> updateCart({
    required int cartId,
    required List<CartProductInput> products,
    bool merge = true,
  }) async {
    final uri = Uri.parse('$_base/carts/$cartId');
    const headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'merge': merge,
      'products': products.map((product) => product.toJson()).toList(),
    });
    final response =
        await (_client?.put(uri, headers: headers, body: body) ??
                http.put(uri, headers: headers, body: body))
            .timeout(requestTimeout);
    if (response.statusCode == 200) {
      return Cart.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to update cart (${response.statusCode})');
  }

  Future<Cart> deleteCart(int cartId) async {
    final uri = Uri.parse('$_base/carts/$cartId');
    final response = await (_client?.delete(uri) ?? http.delete(uri)).timeout(
      requestTimeout,
    );
    if (response.statusCode == 200) {
      return Cart.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to delete cart (${response.statusCode})');
  }

  Cart _cartWithLocalItems(
    int userId,
    Iterable<CartProduct> remoteItems, {
    required int cartId,
  }) {
    final itemsById = <int, CartProduct>{};
    for (final item in [...remoteItems, ...?_localItemsByUser[userId]]) {
      final previous = itemsById[item.id];
      itemsById[item.id] = _copyWithQuantity(
        previous ?? item,
        (previous?.quantity ?? 0) + item.quantity,
      );
    }

    final overrides = _localQuantityOverridesByUser[userId] ?? <int, int>{};
    for (final entry in overrides.entries) {
      final item = itemsById[entry.key];
      if (item != null) {
        itemsById[entry.key] = _copyWithQuantity(item, entry.value);
      }
    }

    final items = itemsById.values.toList();
    return Cart(
      id: cartId,
      products: items,
      total: items.fold<double>(0, (sum, item) => sum + item.total),
      discountedTotal: items.fold<double>(
        0,
        (sum, item) => sum + item.discountedTotal,
      ),
      userId: userId,
      totalProducts: items.length,
      totalQuantity: items.fold<int>(0, (sum, item) => sum + item.quantity),
    );
  }

  CartProduct _copyWithQuantity(CartProduct item, int quantity) {
    return CartProduct(
      id: item.id,
      title: item.title,
      price: item.price,
      quantity: quantity,
      total: item.price * quantity,
      discountPercentage: item.discountPercentage,
      discountedTotal:
          item.price * quantity * (1 - item.discountPercentage / 100),
      thumbnail: item.thumbnail,
    );
  }
}
