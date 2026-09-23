import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morales_advmopbrog/models/cart.dart';
import 'package:morales_advmopbrog/services/cart_service.dart';

CartProduct _product({int id = 10, int quantity = 1}) => CartProduct(
  id: id,
  title: 'Product $id',
  price: 100,
  quantity: quantity,
  total: 100.0 * quantity,
  discountPercentage: 10,
  discountedTotal: 90.0 * quantity,
  thumbnail: '',
);

Map<String, dynamic> _cart(
  int userId,
  List<CartProduct> products, {
  int id = 1,
}) => {
  'id': id,
  'userId': userId,
  'products': products.map((product) => product.toJson()).toList(),
};

http.Response _response(List<Map<String, dynamic>> carts) =>
    http.Response(jsonEncode({'carts': carts}), 200);

void main() {
  test(
    'loads the signed-in user endpoint and returns that user cart',
    () async {
      final service = CartService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://dummyjson.com/carts/user/42');
          return _response([
            _cart(42, [_product(quantity: 2)]),
          ]);
        }),
      );

      final carts = await service.getCartByUser(42);

      expect(carts.single.userId, 42);
      expect(carts.single.products.single.quantity, 2);
      expect(carts.single.total, 200);
      expect(carts.single.discountedTotal, 180);
    },
  );

  test('combines all user carts and merges repeated products', () async {
    final service = CartService(
      client: MockClient(
        (_) async => _response([
          _cart(43, [_product(quantity: 2)]),
          _cart(43, [_product(quantity: 3), _product(id: 20)], id: 2),
          _cart(99, [_product(id: 30)], id: 3),
        ]),
      ),
    );

    final cart = (await service.getCartByUser(43)).single;

    expect(cart.products.map((product) => product.id), [10, 20]);
    expect(cart.products.first.quantity, 5);
    expect(cart.totalProducts, 2);
    expect(cart.totalQuantity, 6);
    expect(cart.total, 600);
    expect(cart.discountedTotal, 540);
  });

  test('a user with no remote cart sees no fabricated products', () async {
    final service = CartService(client: MockClient((_) async => _response([])));

    expect(await service.getCartByUser(44), isEmpty);
    expect(await service.getProductQuantity(userId: 44, productId: 10), 0);
  });

  test('a user with no remote cart can see their local additions', () async {
    final service = CartService(client: MockClient((_) async => _response([])));
    service.addProductLocally(userId: 45, product: _product(quantity: 2));
    service.addProductLocally(userId: 45, product: _product());

    final cart = (await service.getCartByUser(45)).single;

    expect(cart.userId, 45);
    expect(cart.products.single.quantity, 3);
  });

  test('additions and quantity edits remain isolated between users', () async {
    final client = MockClient((request) async {
      final userId = int.parse(request.url.pathSegments.last);
      return _response([
        _cart(userId, [_product()]),
      ]);
    });
    final firstService = CartService(client: client);
    firstService.addProductLocally(userId: 46, product: _product(id: 20));
    firstService.updateProductQuantityLocally(
      userId: 46,
      productId: 10,
      quantity: 4,
    );
    final secondService = CartService(client: client);

    final first = (await secondService.getCartByUser(46)).single;
    final second = (await secondService.getCartByUser(47)).single;

    expect(first.products.map((product) => product.id), [10, 20]);
    expect(first.products.first.quantity, 4);
    expect(second.products.single.id, 10);
    expect(second.products.single.quantity, 1);
  });

  test(
    'adding after a quantity override increments the edited quantity',
    () async {
      final service = CartService(
        client: MockClient(
          (_) async => _response([
            _cart(48, [_product(quantity: 2)]),
          ]),
        ),
      );
      service.updateProductQuantityLocally(
        userId: 48,
        productId: 10,
        quantity: 5,
      );
      service.addProductLocally(userId: 48, product: _product(quantity: 2));

      expect(await service.getProductQuantity(userId: 48, productId: 10), 7);
      final cart = (await service.getCartByUser(48)).single;
      expect(cart.total, 700);
      expect(cart.discountedTotal, 630);

      service.updateProductQuantityLocally(
        userId: 48,
        productId: 10,
        quantity: 0,
      );
      expect(await service.getProductQuantity(userId: 48, productId: 10), 7);
    },
  );

  test(
    'request failures surface instead of returning another user cart',
    () async {
      final service = CartService(
        client: MockClient((_) async => http.Response('Unavailable', 503)),
      );
      service.addProductLocally(userId: 49, product: _product());

      await expectLater(service.getCartByUser(49), throwsException);
      await expectLater(service.getAllCarts(), throwsException);
      await expectLater(service.getCartById(1), throwsException);
    },
  );

  test('network and malformed JSON errors remain visible to callers', () async {
    final offlineService = CartService(
      client: MockClient((_) async => throw http.ClientException('Offline')),
    );
    final invalidService = CartService(
      client: MockClient((_) async => http.Response('not JSON', 200)),
    );

    await expectLater(offlineService.getCartByUser(50), throwsException);
    await expectLater(invalidService.getCartByUser(50), throwsFormatException);
  });

  test('cart requests have a bounded timeout', () async {
    final pending = Completer<http.Response>();
    final service = CartService(
      client: MockClient((_) => pending.future),
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      service.getCartByUser(51),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete(_response([]));
  });

  test('cart mutations use the injected client and preserve user ID', () async {
    final requests = <http.Request>[];
    final service = CartService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_cart(52, [_product()])), 200);
      }),
    );

    await service.addToCart(
      userId: 52,
      products: [const CartProductInput(id: 10, quantity: 1)],
    );
    await service.updateCart(
      cartId: 7,
      products: [const CartProductInput(id: 10, quantity: 3)],
    );
    await service.deleteCart(7);

    expect(requests.map((request) => request.method), [
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.first.url.path, '/carts/add');
    expect(jsonDecode(requests.first.body)['userId'], 52);
    expect(jsonDecode(requests[1].body)['products'][0]['quantity'], 3);
    expect(requests.last.url.path, '/carts/7');
  });
}
