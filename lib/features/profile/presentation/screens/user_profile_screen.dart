import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../chat/data/chat_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _repo = ProfileRepository();
  final _chatRepo = ChatRepository();
  final _scrollController = ScrollController();
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.getProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatLastSeen(String? lastSeenStr, bool online) {
    if (online) return 'в сети';
    if (lastSeenStr == null) return '';
    final lastSeen = DateTime.tryParse(lastSeenStr);
    if (lastSeen == null) return '';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'в сети';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч. назад';
    if (diff.inDays < 7) return 'был(а) ${diff.inDays} дн. назад';
    return 'был(а) давно';
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)} млн ₽';
    }
    return '${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        )} ₽';
  }

  String _formatMemberSince(String createdAtStr) {
    final d = DateTime.tryParse(createdAtStr);
    if (d == null) return '';
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return 'На сайте с ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final isOwnProfile = auth.user?.id == widget.userId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_profile?.displayName ?? 'Профиль'),
      ),
      body: _loading
          ? const SkeletonProfile()
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
              : _profile == null
                  ? const Center(child: Text('Пользователь не найден'))
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Profile header card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Avatar and basic info
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: context.appColors.surfaceWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: context.appColors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      // Avatar
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                                        backgroundImage: _profile!.avatar != null
                                            ? NetworkImage(_profile!.avatar!)
                                            : null,
                                        child: _profile!.avatar == null
                                            ? Text(
                                                _profile!.displayName[0].toUpperCase(),
                                                style: TextStyle(
                                                  color: context.appColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 32,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // Name
                                      Text(
                                        _profile!.displayName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Online status
                                      Builder(builder: (context) {
                                        final statusText = _formatLastSeen(
                                          _profile!.lastSeen,
                                          _profile!.online,
                                        );
                                        if (statusText.isEmpty) return const SizedBox.shrink();
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_profile!.online ||
                                                (_profile!.lastSeen != null &&
                                                    DateTime.now()
                                                            .difference(DateTime.tryParse(
                                                                    _profile!.lastSeen!) ??
                                                                DateTime(2000))
                                                            .inMinutes <
                                                        1))
                                              Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: context.appColors.success,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                color: _profile!.online
                                                    ? context.appColors.success
                                                    : context.appColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                      const SizedBox(height: 12),

                                      // Email
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.email_outlined,
                                              size: 16, color: context.appColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            _profile!.email,
                                            style: TextStyle(
                                              color: context.appColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Phone
                                      if (_profile!.phone != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.phone_outlined,
                                                size: 16, color: context.appColors.textSecondary),
                                            const SizedBox(width: 6),
                                            Text(
                                              _profile!.phone!,
                                              style: TextStyle(
                                                color: context.appColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      // Member since
                                      const SizedBox(height: 12),
                                      Text(
                                        _formatMemberSince(_profile!.createdAt),
                                        style: TextStyle(
                                          color: context.appColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // "Написать" button
                                if (auth.isLoggedIn && !isOwnProfile) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final conv = await _chatRepo
                                              .createConversation(_profile!.id);
                                          if (mounted) {
                                            context.push('/chat/${conv.id}', extra: {
                                              'listingTitle': conv.listingTitle,
                                              'otherUserId': _profile!.id,
                                            });
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Ошибка: $e')),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: const Text('Написать'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(52),
                                      ),
                                    ),
                                  ),
                                ],

                                // Listings header
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    const Text(
                                      'Объявления',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.appColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_profile!.listings.length}',
                                        style: TextStyle(
                                          color: context.appColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Listings list
                        if (_profile!.listings.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Center(
                                child: Text(
                                  'Нет активных объявлений',
                                  style: TextStyle(
                                    color: context.appColors.textMuted,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final listing = _profile!.listings[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ListingCard(
                                      listing: listing,
                                      formatPrice: _formatPrice,
                                      onTap: () =>
                                          context.push('/listing/${listing.id}'),
                                    ),
                                  );
                                },
                                childCount: _profile!.listings.length,
                              ),
                            ),
                          ),

                        // Bottom spacing
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 40),
                        ),
                      ],
                    ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.formatPrice,
    required this.onTap,
  });

  final ProfileListing listing;
  final String Function(double) formatPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 120,
                height: 100,
                child: listing.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: listing.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: context.appColors.surface,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: context.appColors.surface,
                          child: Center(
                            child: Icon(Icons.home_outlined,
                                size: 32, color: context.appColors.textMuted),
                          ),
                        ),
                      )
                    : Container(
                        color: context.appColors.surface,
                        child: Center(
                          child: Icon(Icons.home_outlined,
                              size: 32, color: context.appColors.textMuted),
                        ),
                      ),
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(listing.price),
                      style: TextStyle(
                        color: context.appColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (listing.rooms != null || listing.area != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (listing.rooms != null) ...[
                            Icon(Icons.bed_outlined,
                                size: 14, color: context.appColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              '${listing.rooms}',
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (listing.rooms != null && listing.area != null)
                            const SizedBox(width: 10),
                          if (listing.area != null) ...[
                            Icon(Icons.square_foot,
                                size: 14, color: context.appColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              '${listing.area!.toStringAsFixed(0)} м\u00B2',
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: context.appColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
