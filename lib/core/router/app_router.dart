import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../auth/auth_service.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthService auth) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/',
      redirect: (context, state) {
        if (auth.loading) return null;
        final isLogin = state.matchedLocation == '/login';
        if (!auth.isLoggedIn && (state.matchedLocation == '/create' || state.matchedLocation.startsWith('/my'))) {
          return '/login';
        }
        if (auth.isLoggedIn && isLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ListingsScreen(),
        ),
        GoRoute(
          path: '/listing/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ListingDetailScreen(listingId: id);
          },
        ),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreateListingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
  }
}
