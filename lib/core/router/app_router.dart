import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/main_shell.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/listings/presentation/screens/edit_listing_screen.dart';
import '../../features/listings/presentation/screens/my_listings_screen.dart';
import '../../features/listings/presentation/screens/favorites_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_menu_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/legal/presentation/screens/privacy_screen.dart';
import '../../features/legal/presentation/screens/terms_screen.dart';
import '../auth/auth_service.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthService auth) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        if (auth.loading) return null;
        if (!auth.isLoggedIn && state.matchedLocation != '/login') {
          return '/login';
        }
        if (auth.isLoggedIn && state.matchedLocation == '/login') {
          return '/';
        }
        return null;
      },
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShell(navigationShell: navigationShell);
          },
          branches: [
            // Tab 0: Catalog
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ListingsScreen(),
                ),
              ],
            ),
            // Tab 1: Favorites
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  builder: (context, state) => const FavoritesScreen(),
                ),
              ],
            ),
            // Tab 2: Create Listing
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/create',
                  builder: (context, state) => const CreateListingScreen(),
                ),
              ],
            ),
            // Tab 3: Conversations
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/conversations',
                  builder: (context, state) => const ConversationsScreen(),
                ),
              ],
            ),
            // Tab 4: Profile
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileMenuScreen(),
                ),
              ],
            ),
          ],
        ),
        // Routes that push ON TOP of the shell (no bottom nav)
        GoRoute(
          path: '/listing/:id',
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ListingDetailScreen(listingId: id);
          },
        ),
        GoRoute(
          path: '/listing/:id/edit',
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EditListingScreen(listingId: id);
          },
        ),
        GoRoute(
          path: '/my',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const MyListingsScreen(),
        ),
        GoRoute(
          path: '/chat/:conversationId',
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            final extra = state.extra;
            String? listingTitle;
            String? otherUserId;
            if (extra is Map<String, String?>) {
              listingTitle = extra['listingTitle'];
              otherUserId = extra['otherUserId'];
            } else if (extra is String) {
              listingTitle = extra;
            }
            return ChatScreen(
              conversationId: conversationId,
              listingTitle: listingTitle,
              otherUserId: otherUserId,
            );
          },
        ),
        GoRoute(
          path: '/user/:id',
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return UserProfileScreen(userId: id);
          },
        ),
        GoRoute(
          path: '/notifications',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/privacy',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const PrivacyScreen(),
        ),
        GoRoute(
          path: '/terms',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const TermsScreen(),
        ),
        GoRoute(
          path: '/login',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
  }
}
