import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../widgets/custom_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          title: CustomText(
            text: 'Settings',
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Appearance'),
            ],
            labelPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        body: TabBarView(
          children: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListView(
                  padding: EdgeInsets.all(16.w),
                  children: [
                    SwitchListTile(
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      title: const CustomText(
                        text: 'Dark Mode',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      subtitle: const CustomText(
                        text: 'Toggle between light and dark appearance',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      secondary: Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}