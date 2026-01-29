import 'package:flutter/material.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/router/app_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return AuthServiceScope(
      auth: auth,
      child: MaterialApp.router(
        title: 'Недвижимость',
        theme: AppTheme.light,
        routerConfig: AppRouter.router(auth),
      ),
    );
  }
}
