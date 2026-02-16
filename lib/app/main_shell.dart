import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme/app_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/socket/socket_service.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/notifications/data/notifications_repository.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _chatRepo = ChatRepository();
  final _notifRepo = NotificationsRepository();
  final _socketService = SocketService();
  int _unreadMessages = 0;
  int _unreadNotifications = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadNotificationCount();
    _setupSocket();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadCount();
      _loadNotificationCount();
    });
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    _socketService.on('unread_count', (data) {
      if (!mounted) return;
      final count = (data as Map<String, dynamic>)['count'] as int? ?? 0;
      setState(() => _unreadMessages = count);
    });
    _socketService.on('new_message', (_) {
      if (mounted) _loadUnreadCount();
    });
    _socketService.on('notifications_count', (data) {
      if (!mounted) return;
      final count = (data as Map<String, dynamic>)['count'] as int? ?? 0;
      setState(() => _unreadNotifications = count);
    });
    _socketService.on('notification', (_) {
      if (mounted) _loadNotificationCount();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _socketService.off('unread_count');
    _socketService.off('new_message');
    _socketService.off('notifications_count');
    _socketService.off('notification');
    _socketService.disconnect();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final auth = AuthServiceScope.of(context);
      if (!auth.isLoggedIn) return;
      final count = await _chatRepo.getUnreadCount();
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {}
  }

  void _showUpgradeDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Профессиональный доступ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Размещение объявлений и полный каталог доступны пользователям с активным профессиональным тарифом.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Закрыть',
              style: TextStyle(color: ctx.appColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              launchUrl(
                Uri.parse('https://estate-hub.ru/subscription'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Перейти в личный кабинет'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotificationCount() async {
    try {
      final auth = AuthServiceScope.of(context);
      if (!auth.isLoggedIn) return;
      final count = await _notifRepo.getUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final canCreate = auth.canCreate;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            // Tab index 2 = "Разместить" — block free users
            if (index == 2 && !canCreate) {
              _showUpgradeDialog(context);
              return;
            }
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: context.appColors.surfaceWhite,
          selectedItemColor: context.appColors.primary,
          unselectedItemColor: context.appColors.textMuted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Каталог',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              label: 'Избранное',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.add_circle_outline,
                color: canCreate ? null : context.appColors.textMuted.withValues(alpha: 0.4),
              ),
              label: 'Разместить',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadMessages > 0,
                label: Text(
                  _unreadMessages > 99 ? '99+' : '$_unreadMessages',
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              label: 'Сообщения',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text(
                  _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Icons.person_outline),
              ),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
