import 'package:flutter/material.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/router/app_router.dart';
import 'package:real_estate_app/core/theme/theme_service.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final themeService = ThemeService();
    return ThemeServiceScope(
      themeService: themeService,
      child: AuthServiceScope(
        auth: auth,
        child: Builder(
          builder: (context) {
            final ts = ThemeServiceScope.of(context);
            return MaterialApp.router(
              title: 'Недвижимость',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ts.themeMode,
              routerConfig: AppRouter.router(auth),
            );
          },
        ),
      ),
    );
  }
}
