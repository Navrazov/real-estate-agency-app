import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Shows a bottom sheet prompting the user to upgrade their subscription on the website.
void showUpgradePrompt(BuildContext context, {String? feature}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _UpgradeSheet(feature: feature),
  );
}

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspace_premium,
                size: 40,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Тариф Про',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              feature != null
                  ? 'Функция «$feature» доступна на тарифе Про.'
                  : 'Эта функция доступна на тарифе Про.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ProFeature(icon: Icons.all_inclusive, text: 'Безлимит объявлений', colors: colors),
                  const SizedBox(height: 10),
                  _ProFeature(icon: Icons.chat, text: 'Безлимит диалогов', colors: colors),
                  const SizedBox(height: 10),
                  _ProFeature(icon: Icons.phone, text: 'Просмотр телефонов продавцов', colors: colors),
                  const SizedBox(height: 10),
                  _ProFeature(icon: Icons.trending_up, text: 'Приоритет в выдаче', colors: colors),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Оформить на сайте estate-hub.ru'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Позже',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  const _ProFeature({
    required this.icon,
    required this.text,
    required this.colors,
  });

  final IconData icon;
  final String text;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, size: 20, color: colors.success),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
