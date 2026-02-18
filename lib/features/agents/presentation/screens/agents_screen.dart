import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../chat/data/chat_repository.dart';

class Agent {
  Agent({
    required this.id,
    this.name,
    this.avatar,
    this.phone,
    this.agency,
    required this.activeListings,
    required this.createdAt,
    this.lastSeen,
    required this.online,
  });

  final String id;
  final String? name;
  final String? avatar;
  final String? phone;
  final String? agency;
  final int activeListings;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool online;

  String get displayName => name ?? 'Агент';

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      agency: json['agency'] as String?,
      activeListings: (json['activeListings'] is num) ? (json['activeListings'] as num).toInt() : 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
      online: json['online'] as bool? ?? false,
    );
  }
}

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  final _api = ApiClient();
  final _chatRepo = ChatRepository();
  List<Agent>? _agents;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agents = await _api.get<List<Agent>>(
        '/users/agents',
        (data) => (data as List<dynamic>)
            .map((e) => Agent.fromJson(e as Map<String, dynamic>))
            .toList(),
        withAuth: false,
      );
      if (mounted) setState(() => _agents = agents);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(Agent agent) async {
    final auth = AuthServiceScope.of(context);
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    try {
      final conversation = await _chatRepo.createConversation(agent.id);
      if (mounted) {
        context.push(
          '/chat/${conversation.id}',
          extra: <String, String?>{'otherUserId': agent.id},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return '';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 30) return '${diff.inDays} дн. назад';
    return '${lastSeen.day}.${lastSeen.month.toString().padLeft(2, '0')}.${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Агенты'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
              : _agents == null || _agents!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: context.appColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Агенты не найдены',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Пока нет агентов с активными объявлениями',
                            style: TextStyle(color: context.appColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _agents!.length,
                        itemBuilder: (context, i) {
                          final agent = _agents![i];
                          return _AgentCard(
                            agent: agent,
                            onTap: () => context.push('/user/${agent.id}'),
                            onChat: auth.isLoggedIn && auth.user?.id != agent.id
                                ? () => _startChat(agent)
                                : null,
                            formatLastSeen: _formatLastSeen,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.onTap,
    this.onChat,
    required this.formatLastSeen,
  });

  final Agent agent;
  final VoidCallback onTap;
  final VoidCallback? onChat;
  final String Function(DateTime?) formatLastSeen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                    backgroundImage: agent.avatar != null
                        ? CachedNetworkImageProvider(agent.avatar!)
                        : null,
                    child: agent.avatar == null
                        ? Text(
                            agent.displayName.isNotEmpty
                                ? agent.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.primary,
                            ),
                          )
                        : null,
                  ),
                  if (agent.online)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: context.appColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.appColors.surfaceWhite, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (agent.agency != null) ...[
                      Text(
                        agent.agency!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        Icon(Icons.list_alt, size: 14, color: context.appColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${agent.activeListings} ${_pluralize(agent.activeListings, 'объявление', 'объявления', 'объявлений')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.textMuted,
                          ),
                        ),
                        if (!agent.online && agent.lastSeen != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: context.appColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            formatLastSeen(agent.lastSeen),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.textMuted,
                            ),
                          ),
                        ],
                        if (agent.online)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'онлайн',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (agent.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: context.appColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            agent.phone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.appColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Chat button
              if (onChat != null)
                IconButton(
                  onPressed: onChat,
                  icon: Icon(Icons.chat_outlined, color: context.appColors.primary),
                  tooltip: 'Написать',
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _pluralize(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
    return many;
  }
}
