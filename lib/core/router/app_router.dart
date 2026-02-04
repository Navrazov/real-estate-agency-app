import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/listings/presentation/screens/edit_listing_screen.dart';
import '../../features/listings/presentation/screens/my_listings_screen.dart';
import '../../features/listings/presentation/screens/favorites_screen.dart';
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
        final protectedRoutes = ['/create', '/my', '/favorites'];
        final isProtected = protectedRoutes.any(
          (r) => state.matchedLocation == r || state.matchedLocation.startsWith('$r/'),
        );
        final isEditRoute = state.matchedLocation.contains('/edit');
        
        if (!auth.isLoggedIn && (isProtected || isEditRoute)) {
          return '/login';
        }
        if (auth.isLoggedIn && state.matchedLocation == '/login') {
          return '/';
        }
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
          path: '/listing/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EditListingScreen(listingId: id);
          },
        ),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreateListingScreen(),
        ),
        GoRoute(
          path: '/my',
          builder: (context, state) => const MyListingsScreen(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
  }
}
