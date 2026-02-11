import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/socket/socket_service.dart';
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _socketService.off('new_message');
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
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: const Text('Удалить у всех', style: TextStyle(color: AppColors.error)),
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
    final now = DateTime.now();
    final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
    if (isToday) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_otherUserProfile?.displayName ?? 'Чат'),
              if (_otherUserProfile != null)
                Row(
                  children: [
                    if (_otherUserProfile!.online || _formatLastSeen(_otherUserProfile!.lastSeen, _otherUserProfile!.online) == 'в сети')
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _formatLastSeen(_otherUserProfile!.lastSeen, _otherUserProfile!.online),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: _otherUserProfile!.online ? Colors.green : null,
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
                          ? const Center(
                              child: Text(
                                'Нет сообщений. Начните диалог!',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMine = msg.senderId == currentUserId;

                                return Padding(
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
                                                ? AppColors.primary
                                                : AppColors.surface,
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
                                                    color: isMine ? Colors.white : AppColors.textPrimary,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    _formatTime(msg.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isMine
                                                          ? Colors.white.withOpacity(0.7)
                                                          : AppColors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceWhite,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  hintText: 'Введите сообщение...',
                                  hintStyle: const TextStyle(color: AppColors.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                textInputAction: TextInputAction.send,
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
