import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:morales_advmopbrog/screens/product_screen.dart';
import 'package:morales_advmopbrog/services/product_service.dart';

void main() {
  testWidgets('product search filters the loaded catalogue', (tester) async {
    final service = ProductService(
      client: MockClient((request) async {
        expect(request.url.path, '/products');
        return http.Response(
          jsonEncode({
            'products': [
              {'id': 1, 'title': 'NU Shirt', 'price': 449.99},
              {'id': 2, 'title': 'NU Jacket', 'price': 999.99},
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(412, 715),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, _) => MaterialApp(
          home: ProductScreen(userId: 42, productService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NU Shirt'), findsOneWidget);
    expect(find.text('NU Jacket'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'shirt');
    await tester.pumpAndSettle();
    expect(find.text('NU Shirt'), findsOneWidget);
    expect(find.text('NU Jacket'), findsNothing);

    await tester.enterText(find.byType(TextField), 'unavailable product');
    await tester.pumpAndSettle();
    expect(find.text('No products found.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('NU Jacket'), findsOneWidget);
  });

  test(
    'catalogue falls back to the existing products asset on network failure',
    () async {
      final service = ProductService(
        client: MockClient((_) async {
          throw http.ClientException('Offline');
        }),
      );
      final products = await service.getAllProducts();
      expect(products.any((product) => product.title == 'NU Shirt'), isTrue);
      expect(products.any((product) => product.title == 'NU Jacket'), isTrue);
    },
  );
}
