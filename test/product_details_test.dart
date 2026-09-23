import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morales_advmopbrog/models/product_model.dart';
import 'package:morales_advmopbrog/screens/product_details_screen.dart';
import 'package:morales_advmopbrog/services/cart_service.dart';

const _productId = 123;

final _product = Product.fromJson({
  'id': _productId,
  'title': 'Campus notebook',
  'description': 'A notebook for your next class.',
  'price': 100,
  'discountPercentage': 10,
  'rating': 4.5,
});

Map<String, dynamic> _cart(int userId, int quantity) => {
  'id': 501,
  'userId': userId,
  'products': [
    {
      'id': _productId,
      'title': 'Campus notebook',
      'price': 100,
      'quantity': quantity,
      'total': 100 * quantity,
      'discountPercentage': 10,
      'discountedTotal': 90 * quantity,
      'thumbnail': '',
    },
  ],
  'total': 100 * quantity,
  'discountedTotal': 90 * quantity,
  'totalProducts': 1,
  'totalQuantity': quantity,
};

http.Response _cartResponse(int userId, int quantity) => http.Response(
  jsonEncode({
    'carts': [_cart(userId, quantity)],
  }),
  200,
);

Future<void> _openDetails(
  WidgetTester tester,
  CartService service,
  int userId, {
  int quantityInCart = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProductDetailsScreen(
        product: _product,
        userId: userId,
        showAddToCart: true,
        quantityInCart: quantityInCart,
        cartService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

// Model a quantity snapshot that was already read before a slow initial Future
// completes. Later calls use the actual HTTP-backed service and local merge.
class _DelayedInitialCartService extends CartService {
  _DelayedInitialCartService({required http.Client client})
    : super(client: client);

  final initialQuantity = Completer<int>();
  int quantityReads = 0;

  @override
  Future<int> getProductQuantity({
    required int userId,
    required int productId,
  }) {
    quantityReads++;
    if (quantityReads == 1) return initialQuantity.future;
    return super.getProductQuantity(userId: userId, productId: productId);
  }
}

void main() {
  testWidgets('details loads quantity from the authenticated user cart', (
    tester,
  ) async {
    const userId = 71001;
    final requests = <http.Request>[];
    final service = CartService(
      client: MockClient((request) async {
        requests.add(request);
        return _cartResponse(userId, 4);
      }),
    );

    await _openDetails(tester, service, userId);

    expect(find.text('Quantity in Cart: 4'), findsOneWidget);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/carts/user/$userId');
  });

  testWidgets(
    'add uses the authenticated id and commits local quantity only after success',
    (tester) async {
      const userId = 71002;
      final postResponse = Completer<http.Response>();
      final posts = <http.Request>[];
      final service = CartService(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts.add(request);
            return postResponse.future;
          }
          expect(request.url.path, '/carts/user/$userId');
          return _cartResponse(userId, 2);
        }),
      );
      await _openDetails(tester, service, userId);
      expect(find.text('Quantity in Cart: 2'), findsOneWidget);

      await _tapAdd(tester);
      expect(posts, hasLength(1));
      expect(posts.single.url.path, '/carts/add');
      expect(jsonDecode(posts.single.body), {
        'userId': userId,
        'products': [
          {'id': _productId, 'quantity': 1},
        ],
      });
      expect(find.text('Quantity in Cart: 2'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        await service.getProductQuantity(userId: userId, productId: _productId),
        2,
      );

      // A repeated tap while the request is pending cannot send a second POST.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(posts, hasLength(1));

      postResponse.complete(http.Response(jsonEncode(_cart(userId, 1)), 201));
      await tester.pumpAndSettle();
      expect(find.text('Added to cart'), findsOneWidget);
      expect(find.text('Quantity in Cart: 3'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        await service.getProductQuantity(userId: userId, productId: _productId),
        3,
      );

      // The unchanged remote response still merges the successful local edit when
      // another service instance opens this user's cart in the same session.
      final reopenedService = CartService(
        client: MockClient((_) async => _cartResponse(userId, 2)),
      );
      expect(
        await reopenedService.getProductQuantity(
          userId: userId,
          productId: _productId,
        ),
        3,
      );
    },
  );

  testWidgets(
    'failed quantity GET prevents POST and preserves the displayed cart',
    (tester) async {
      const userId = 71003;
      var failGet = false;
      var postCalls = 0;
      final service = CartService(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            postCalls++;
            return http.Response(jsonEncode(_cart(userId, 1)), 201);
          }
          return failGet
              ? http.Response('Unavailable', 503)
              : _cartResponse(userId, 4);
        }),
      );
      await _openDetails(tester, service, userId);
      failGet = true;
      await _tapAdd(tester);
      await tester.pumpAndSettle();

      expect(postCalls, 0);
      expect(find.text('Quantity in Cart: 4'), findsOneWidget);
      expect(
        find.text('Unable to add to cart. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      failGet = false;
      expect(
        await service.getProductQuantity(userId: userId, productId: _productId),
        4,
      );
    },
  );

  testWidgets('failed POST preserves local quantity and allows a retry', (
    tester,
  ) async {
    const userId = 71004;
    var failPost = true;
    var postCalls = 0;
    final service = CartService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          postCalls++;
          return failPost
              ? http.Response('Unavailable', 503)
              : http.Response(jsonEncode(_cart(userId, 1)), 201);
        }
        return _cartResponse(userId, 2);
      }),
    );
    await _openDetails(tester, service, userId);
    await _tapAdd(tester);
    await tester.pumpAndSettle();

    expect(postCalls, 1);
    expect(find.text('Quantity in Cart: 2'), findsOneWidget);
    expect(
      find.text('Unable to add to cart. Please try again.'),
      findsOneWidget,
    );
    expect(
      await service.getProductQuantity(userId: userId, productId: _productId),
      2,
    );

    failPost = false;
    await _tapAdd(tester);
    await tester.pumpAndSettle();
    expect(postCalls, 2);
    expect(find.text('Quantity in Cart: 3'), findsOneWidget);
    expect(
      await service.getProductQuantity(userId: userId, productId: _productId),
      3,
    );
  });

  testWidgets('late initial quantity cannot overwrite a successful add', (
    tester,
  ) async {
    const userId = 71005;
    final service = _DelayedInitialCartService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode(_cart(userId, 1)), 201);
        }
        return _cartResponse(userId, 2);
      }),
    );
    await _openDetails(tester, service, userId);
    await _tapAdd(tester);
    await tester.pumpAndSettle();
    expect(find.text('Quantity in Cart: 3'), findsOneWidget);

    service.initialQuantity.complete(2);
    await tester.pumpAndSettle();
    expect(find.text('Quantity in Cart: 3'), findsOneWidget);
    expect(find.text('Quantity in Cart: 2'), findsNothing);
    expect(
      await service.getProductQuantity(userId: userId, productId: _productId),
      3,
    );
  });
}
