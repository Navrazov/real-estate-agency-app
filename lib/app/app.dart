import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/router/app_router.dart';
import 'package:real_estate_app/core/theme/theme_service.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';

class RealEstateApp extends StatefulWidget {
  const RealEstateApp({super.key});

  @override
  State<RealEstateApp> createState() => _RealEstateAppState();
}

class _RealEstateAppState extends State<RealEstateApp> {
  late final AuthService _auth;
  late final ThemeService _themeService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _themeService = ThemeService();
    _router = AppRouter.router(_auth);
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    _themeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeServiceScope(
      themeService: _themeService,
      child: AuthServiceScope(
        auth: _auth,
        child: Builder(
          builder: (context) {
            final ts = ThemeServiceScope.of(context);
            return MaterialApp.router(
              title: 'Недвижимость',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ts.themeMode,
              routerConfig: _router,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('ru'),
                Locale('en'),
              ],
              locale: const Locale('ru'),
            );
          },
        ),
      ),
    );
  }
}
