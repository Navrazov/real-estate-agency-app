import 'package:flutter/material.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../data/notifications_repository.dart';
import '../../domain/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _repo.getAll(page: _page);
      if (mounted) {
        setState(() {
          _notifications = response.items;
          _totalPages = response.totalPages;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _repo.markRead(id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx >= 0) {
          final n = _notifications[idx];
          _notifications[idx] = AppNotification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            read: true,
            createdAt: n.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllRead();
      setState(() {
        _notifications = _notifications
            .map((n) => AppNotification(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  read: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
    } catch (_) {}
  }

  String _formatTime(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'Нет уведомлений',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Здесь будут появляться ваши уведомления',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length +
                        (_page < _totalPages ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _notifications.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _page++);
                                _load();
                              },
                              child: const Text('Загрузить ещё'),
                            ),
                          ),
                        );
                      }

                      final n = _notifications[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: n.read ? null : AppColors.primary.withOpacity(0.05),
                        child: InkWell(
                          onTap: () {
                            if (!n.read) _markRead(n.id);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 6, right: 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: n.read
                                        ? AppColors.border
                                        : AppColors.primary,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: TextStyle(
                                                fontWeight: n.read
                                                    ? FontWeight.w500
                                                    : FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTime(n.createdAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: TextStyle(
                                          color: n.read
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
