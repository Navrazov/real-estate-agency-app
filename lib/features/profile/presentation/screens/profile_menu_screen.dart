import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/theme/theme_service.dart';

class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final user = auth.user;
    final colors = context.appColors;
    final themeService = ThemeServiceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  backgroundImage: user?.avatar != null ? NetworkImage(user!.avatar!) : null,
                  child: user?.avatar == null
                      ? Text(
                          user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Пользователь',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (user?.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.phone!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Theme toggle
          Container(
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: colors.surfaceWhite,
              border: Border.all(color: colors.border, width: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                context.isDark ? Icons.dark_mode : Icons.light_mode,
                color: colors.textSecondary,
              ),
              title: Text(context.isDark ? 'Тёмная тема' : 'Светлая тема'),
              trailing: Switch(
                value: context.isDark,
                onChanged: (_) => themeService.toggleTheme(),
                activeThumbColor: colors.primary,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),

          // Menu items
          _MenuTile(
            icon: Icons.list_alt,
            title: 'Мои объявления',
            onTap: () => context.push('/my'),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: 'Уведомления',
            onTap: () => context.push('/notifications'),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            onTap: () => context.push('/settings'),
          ),
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Помощь',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                auth.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Вы вышли из аккаунта')),
                );
              },
              icon: Icon(Icons.logout, color: colors.error),
              label: Text('Выйти', style: TextStyle(color: colors.error)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: colors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: colors.surfaceWhite,
        border: Border.all(color: colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.textSecondary),
        title: Text(title),
        trailing: Icon(Icons.chevron_right, color: colors.textMuted),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
