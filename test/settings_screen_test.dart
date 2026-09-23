import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:morales_advmopbrog/providers/theme_provider.dart';
import 'package:morales_advmopbrog/screens/settings_screen.dart';

void main() {
  testWidgets('settings screen shows appearance tab with dark mode toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: ScreenUtilInit(
          designSize: const Size(412, 715),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, _) => const MaterialApp(home: SettingsScreen()),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
