import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/chat_repository.dart';
import '../../domain/message.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/user_profile.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.listingTitle, this.otherUserId});

  final String conversationId;
  final String? listingTitle;
  final String? otherUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo = ChatRepository();
  final _profileRepo = ProfileRepository();
  final _socketService = SocketService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  UserProfile? _otherUserProfile;
  bool _isTyping = false;
  int _lastTypingEmit = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _setupSocket();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    if (widget.otherUserId == null) return;
    try {
      final profile = await _profileRepo.getProfile(widget.otherUserId!);
      if (mounted) setState(() => _otherUserProfile = profile);
    } catch (_) {}
  }

  String _formatLastSeen(String? dateStr, bool online) {
    if (online) return 'в сети';
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 2) return 'в сети';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч. назад';
    return 'был(а) ${d.day}.${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    _socketService.on('new_message', (data) {
      if (!mounted) return;
      final msg = Message.fromJson(data as Map<String, dynamic>);
      if (msg.conversationId == widget.conversationId) {
        setState(() {
          _messages.add(msg);
        });
        _scrollToBottom();
        // Mark as read via socket for instant badge update
        _socketService.emit('mark_read', {'conversationId': widget.conversationId});
      }
    });
    _socketService.on('messages_read', (data) {
      if (!mounted) return;
      final convId = (data as Map<String, dynamic>)['conversationId'] as String;
      if (convId == widget.conversationId) {
        final currentUserId = AuthServiceScope.of(context).user?.id;
        setState(() {
          _messages = _messages.map((m) {
            if (m.senderId == currentUserId) return m.copyWith(read: true);
            return m;
          }).toList();
        });
      }
    });
    // Online/offline status updates
    _socketService.on('user_online', (data) {
      if (!mounted) return;
      final uid = (data as Map<String, dynamic>)['userId'] as String;
      if (uid == widget.otherUserId && _otherUserProfile != null) {
        setState(() {
          _otherUserProfile = _otherUserProfile!.copyWith(online: true);
        });
      }
    });
    _socketService.on('user_offline', (data) {
      if (!mounted) return;
      final map = data as Map<String, dynamic>;
      final uid = map['userId'] as String;
      if (uid == widget.otherUserId && _otherUserProfile != null) {
        setState(() {
          _otherUserProfile = _otherUserProfile!.copyWith(
            online: false,
            lastSeen: map['lastSeen'] as String?,
          );
          _isTyping = false;
        });
      }
    });
    // Typing indicator
    _socketService.on('typing', (data) {
      if (!mounted) return;
      final map = data as Map<String, dynamic>;
      final convId = map['conversationId'] as String;
      final uid = map['userId'] as String;
      if (convId == widget.conversationId && uid == widget.otherUserId) {
        setState(() => _isTyping = true);
        // Auto-clear after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _socketService.off('new_message');
    _socketService.off('messages_read');
    _socketService.off('user_online');
    _socketService.off('user_offline');
    _socketService.off('typing');
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _repo.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
        });
        _scrollToBottom();
        // Mark as read via both REST and socket for instant badge update
        _repo.markRead(widget.conversationId);
        _socketService.emit('mark_read', {'conversationId': widget.conversationId});
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypingEmit > 2000) {
      _lastTypingEmit = now;
      _socketService.emit('typing', {'conversationId': widget.conversationId});
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);

    try {
      final msg = await _repo.sendMessage(widget.conversationId, text);
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _showDeleteMessageSheet(Message msg, bool isMine) {
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
                _deleteMessage(msg.id, forBoth: false);
              },
            ),
            if (isMine)
              ListTile(
                leading: Icon(Icons.delete_forever, color: context.appColors.error),
                title: Text('Удалить у всех', style: TextStyle(color: context.appColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg.id, forBoth: true);
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

  Future<void> _deleteMessage(String messageId, {required bool forBoth}) async {
    try {
      await _repo.deleteMessage(messageId, forBoth: forBoth);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == messageId);
        });
        // If no messages left, server auto-hides the conversation — go back
        if (_messages.isEmpty && mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  String _formatTime(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current = DateTime.tryParse(_messages[index].createdAt);
    final previous = DateTime.tryParse(_messages[index - 1].createdAt);
    if (current == null || previous == null) return false;
    return current.day != previous.day || current.month != previous.month || current.year != previous.year;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final currentUserId = auth.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.otherUserId != null
              ? () => context.push('/user/${widget.otherUserId}')
              : null,
          child: Row(
            children: [
              if (_otherUserProfile != null) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                  backgroundImage: _otherUserProfile!.avatar != null
                      ? NetworkImage(_otherUserProfile!.avatar!)
                      : null,
                  child: _otherUserProfile!.avatar == null
                      ? Text(
                          _otherUserProfile!.displayName.isNotEmpty
                              ? _otherUserProfile!.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: context.appColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_otherUserProfile?.displayName ?? 'Чат'),
                    if (_isTyping)
                      Text(
                        'печатает...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: context.appColors.success,
                        ),
                      )
                    else if (_otherUserProfile != null)
                      Row(
                        children: [
                          if (_otherUserProfile!.online || _formatLastSeen(_otherUserProfile!.lastSeen, _otherUserProfile!.online) == 'в сети')
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: context.appColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _formatLastSeen(_otherUserProfile!.lastSeen, _otherUserProfile!.online),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: _otherUserProfile!.online ? context.appColors.success : context.appColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else if (widget.listingTitle != null)
                      Text(
                        widget.listingTitle!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const SkeletonMessages()
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
              : Column(
                  children: [
                    // Messages
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Нет сообщений. Начните диалог!',
                                style: TextStyle(color: context.appColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMine = msg.senderId == currentUserId;
                                final showDate = _shouldShowDateSeparator(index);
                                final msgDate = DateTime.tryParse(msg.createdAt);

                                return Column(
                                  children: [
                                    if (showDate && msgDate != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: context.appColors.surface,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _formatDateSeparator(msgDate),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.appColors.textMuted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Align(
                                        alignment: isMine
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: GestureDetector(
                                          onLongPress: () => _showDeleteMessageSheet(msg, isMine),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: isMine
                                                    ? context.appColors.primary
                                                    : context.appColors.surface,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(16),
                                                  topRight: const Radius.circular(16),
                                                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                                                  bottomRight: Radius.circular(isMine ? 4 : 16),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                child: Wrap(
                                                  alignment: WrapAlignment.end,
                                                  spacing: 6,
                                                  runSpacing: 2,
                                                  crossAxisAlignment: WrapCrossAlignment.end,
                                                  children: [
                                                    Text(
                                                      msg.text,
                                                      style: TextStyle(
                                                        color: isMine ? Colors.white : context.appColors.textPrimary,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            _formatTime(msg.createdAt),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isMine
                                                                  ? Colors.white.withValues(alpha: 0.7)
                                                                  : context.appColors.textMuted,
                                                            ),
                                                          ),
                                                          if (isMine) ...[
                                                            const SizedBox(width: 3),
                                                            Icon(
                                                              msg.read ? Icons.done_all : Icons.done,
                                                              size: 14,
                                                              color: msg.read
                                                                  ? Colors.white
                                                                  : Colors.white.withValues(alpha: 0.7),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceWhite,
                        border: Border(top: BorderSide(color: context.appColors.border)),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  hintText: 'Введите сообщение...',
                                  hintStyle: TextStyle(color: context.appColors.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: context.appColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: context.appColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: context.appColors.primary),
                                  ),
                                  filled: true,
                                  fillColor: context.appColors.surface,
                                ),
                                textInputAction: TextInputAction.send,
                                onChanged: _onTextChanged,
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
