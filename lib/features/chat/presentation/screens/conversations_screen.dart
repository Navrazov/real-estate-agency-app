import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/chat_repository.dart';
import '../../domain/message.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _repo = ChatRepository();
  final _socketService = SocketService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _setupSocket();
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    _socketService.on('new_message', (data) {
      if (mounted) {
        _load(); // Refresh conversations on new message
      }
    });
  }

  @override
  void dispose() {
    _socketService.off('new_message');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final conversations = await _repo.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showDeleteConversationSheet(Conversation conv) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить у себя'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteConversation(conv.id, forBoth: false);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: context.appColors.error),
              title: Text('Удалить у всех', style: TextStyle(color: context.appColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteConversation(conv.id, forBoth: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteConversation(String conversationId, {required bool forBoth}) async {
    try {
      await _repo.deleteConversation(conversationId, forBoth: forBoth);
      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.id == conversationId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
    if (isToday) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
      ),
      body: _loading
          ? const SkeletonConversationList()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: context.appColors.error),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                    ],
                  ),
                )
              : !auth.isLoggedIn
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: context.appColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Войдите, чтобы просматривать сообщения',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.appColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push('/login'),
                            child: const Text('Войти'),
                          ),
                        ],
                      ),
                    )
                  : _conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: context.appColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                'Нет диалогов',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Начните диалог на странице объявления',
                                style: TextStyle(color: context.appColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final displayName = conv.otherUser?.displayName ?? 'Пользователь';
                              final initial = displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?';

                              final isOnline = conv.otherUser?.online ?? false;

                              return ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          color: context.appColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(conv.lastMessageAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.appColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (conv.listingTitle != null)
                                      Text(
                                        conv.listingTitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.appColors.primary,
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.lastMessage ?? 'Нет сообщений',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: conv.unreadCount > 0
                                                  ? context.appColors.textPrimary
                                                  : context.appColors.textSecondary,
                                              fontWeight: conv.unreadCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (conv.unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.appColors.primary,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${conv.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await context.push('/chat/${conv.id}', extra: {
                                    'listingTitle': conv.listingTitle,
                                    'otherUserId': conv.otherUser?.id,
                                  });
                                  // Refresh conversations when returning from chat
                                  if (mounted) _load();
                                },
                                onLongPress: () => _showDeleteConversationSheet(conv),
                              );
                            },
                          ),
                        ),
    );
  }
}
