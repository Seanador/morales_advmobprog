import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morales_advmopbrog/models/cart.dart';
import 'package:morales_advmopbrog/screens/cart_screen.dart';
import 'package:morales_advmopbrog/services/cart_service.dart';

class _FakeCartService extends CartService {
  final Future<List<Cart>> Function(int userId) load;
  final List<int> requestedUsers = [];
  final List<List<int>> quantityChanges = [];

  _FakeCartService(this.load);

  @override
  Future<List<Cart>> getCartByUser(int userId) {
    requestedUsers.add(userId);
    return load(userId);
  }

  @override
  void updateProductQuantityLocally({
    required int userId,
    required int productId,
    required int quantity,
  }) {
    quantityChanges.add([userId, productId, quantity]);
  }
}

Cart _cart(int userId, {int quantity = 2}) => Cart(
  id: 1,
  userId: userId,
  products: [
    CartProduct(
      id: 10,
      title: 'Your product',
      price: 100,
      quantity: quantity,
      total: 100.0 * quantity,
      discountPercentage: 10,
      discountedTotal: 90.0 * quantity,
      thumbnail: '',
    ),
  ],
  total: 100.0 * quantity,
  discountedTotal: 90.0 * quantity,
  totalProducts: 1,
  totalQuantity: quantity,
);

Widget _app(CartService service, {int userId = 208}) => MaterialApp(
  home: CartScreen(userId: userId, cartService: service),
);

void main() {
  testWidgets('loads the provided user ID and displays a loading state', (
    tester,
  ) async {
    final pending = Completer<List<Cart>>();
    final service = _FakeCartService((_) => pending.future);

    await tester.pumpWidget(_app(service));

    expect(service.requestedUsers, [208]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([_cart(208)]);
    await tester.pumpAndSettle();
    expect(find.text('Your product'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an empty user cart displays an empty state', (tester) async {
    final service = _FakeCartService((_) async => []);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty.'), findsOneWidget);
    expect(find.text('Confirm Order'), findsNothing);
    expect(find.text('NU Shirt 1'), findsNothing);
  });

  testWidgets('a failed load can be retried successfully', (tester) async {
    var attempts = 0;
    final service = _FakeCartService((userId) async {
      if (attempts++ == 0) throw Exception('Offline');
      return [_cart(userId)];
    });

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load your cart.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.requestedUsers, [208, 208]);
    expect(find.text('Your product'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('switching users loads fresh quantities for the new user', (
    tester,
  ) async {
    final service = _FakeCartService(
      (userId) async => [_cart(userId, quantity: userId == 208 ? 2 : 5)],
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(_app(service, userId: 209));
    await tester.pumpAndSettle();

    expect(service.requestedUsers, [208, 209]);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('quantity controls update the current user cart and totals', (
    tester,
  ) async {
    final service = _FakeCartService((userId) async => [_cart(userId)]);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();

    expect(service.quantityChanges, [
      [208, 10, 3],
    ]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Item total: \u20b1300.00'), findsOneWidget);
    expect(find.text('\u20b1270.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('returning from product details refreshes cart quantities', (
    tester,
  ) async {
    var quantity = 2;
    final service = _FakeCartService(
      (userId) async => [_cart(userId, quantity: quantity)],
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your product'));
    await tester.pumpAndSettle();
    expect(find.text('Quantity in Cart: 2'), findsOneWidget);

    quantity = 5;
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(service.requestedUsers, [208, 208]);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
