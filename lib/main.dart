import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/user.dart';
import 'providers/theme_provider.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/splash_screen.dart';
import 'services/user_service.dart';
import 'services/product_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: 'assets/.env', isOptional: true);
  runApp(const MoralesAdvMobProg());
}

class MoralesAdvMobProg extends StatelessWidget {
  const MoralesAdvMobProg({super.key, this.userService, this.productService});

  final UserService? userService;
  final ProductService? productService;

  @override
  Widget build(BuildContext context) {
    final service = userService ?? UserService();
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: ScreenUtilInit(
        designSize: const Size(412, 715),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          final theme = context.watch<ThemeProvider>();
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            title: 'NU BD Exchange',
            //Enhancement 1
            // Every app launch checks the saved session before opening the shop.
            initialRoute: '/',
            // A browser deep link must also validate the session before showing data.
            onGenerateInitialRoutes: (_) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/'),
                builder: (_) => SplashScreen(userService: service),
              ),
            ],
            routes: {
              '/': (_) => SplashScreen(userService: service),
              '/splash': (_) => SplashScreen(userService: service),
              //Enhancement 2
              '/signin': (context) {
                final arguments = ModalRoute.of(context)?.settings.arguments;
                return SigninScreen(
                  userService: service,
                  initialError: arguments is String ? arguments : null,
                );
              },
              //Enhancement 3
              // Resolve both routes from saved data, never a default user ID.
              '/home': (_) => _SavedUserRoute(
                userService: service,
                builder: (user) => HomeScreen(
                  user: user,
                  userService: service,
                  productService: productService,
                ),
              ),
              '/cart': (_) => _SavedUserRoute(
                userService: service,
                builder: (user) => CartScreen(userId: user.id),
              ),
              '/settings': (_) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

class _SavedUserRoute extends StatefulWidget {
  const _SavedUserRoute({required this.userService, required this.builder});

  final UserService userService;
  final Widget Function(User user) builder;

  @override
  State<_SavedUserRoute> createState() => _SavedUserRouteState();
}

class _SavedUserRouteState extends State<_SavedUserRoute> {
  late Future<User> _user = widget.userService.getUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _user,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load your account.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _user = widget.userService.getUser();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null || !user.hasSession) {
          return SigninScreen(userService: widget.userService);
        }
        return widget.builder(user);
      },
    );
  }
}
