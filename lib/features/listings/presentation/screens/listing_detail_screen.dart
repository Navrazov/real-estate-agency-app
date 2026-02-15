import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/widgets/listings_map.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../chat/data/chat_repository.dart';
import '../../data/listings_repository.dart';
import '../../domain/listing.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _repo = ListingsRepository();
  final _chatRepo = ChatRepository();
  final _scrollController = ScrollController();
  Listing? _listing;
  bool _loading = true;
  String? _error;
  int _imageIndex = 0;
  bool _isFavorite = false;

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
      final listing = await _repo.getById(widget.listingId);
      if (mounted) {
        setState(() {
          _listing = listing;
          _isFavorite = listing.isFavorite;
        });
        // Ensure scroll starts at top
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

  Future<void> _toggleFavorite() async {
    final auth = AuthServiceScope.of(context);
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    try {
      final result = await _repo.toggleFavorite(widget.listingId);
      final favorites = (result['favorites'] as List<dynamic>).cast<String>();
      auth.updateFavorites(favorites);
      setState(() => _isFavorite = result['isFavorite'] as bool);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: TextStyle(color: context.appColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || _listing == null) return;
    try {
      await _repo.delete(_listing!.id);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final isOwner = _listing != null && auth.user?.id == _listing!.authorId;
    final isAdmin = auth.user?.isAdmin ?? false;
    final canEdit = isOwner || isAdmin;
    final images = _listing?.images ?? [];
    final hasCoords = _listing?.lat != null && _listing?.lng != null;

    return Scaffold(
      body: _loading
          ? const SkeletonListingDetail()
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
              : _listing == null
                  ? const Center(child: Text('Объявление не найдено'))
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Image Header
                        SliverAppBar(
                          expandedHeight: 300,
                          pinned: true,
                          leading: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_back, color: context.appColors.textPrimary),
                            ),
                            onPressed: () => context.pop(),
                          ),
                          actions: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: _isFavorite ? const Color(0xFFE8788A) : context.appColors.textPrimary,
                                ),
                              ),
                              onPressed: _toggleFavorite,
                            ),
                            if (canEdit) ...[
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.edit, color: context.appColors.textPrimary),
                                ),
                                onPressed: () => context.push('/listing/${widget.listingId}/edit'),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.delete_outline, color: context.appColors.error),
                                ),
                                onPressed: _delete,
                              ),
                            ],
                            const SizedBox(width: 8),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                images.isNotEmpty
                                    ? PageView.builder(
                                        itemCount: images.length,
                                        onPageChanged: (i) => setState(() => _imageIndex = i),
                                        itemBuilder: (context, i) => Image.network(
                                          images[i],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: context.appColors.surface,
                                            child: const Center(
                                              child: Text('🏠', style: TextStyle(fontSize: 64)),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: context.appColors.surface,
                                        child: const Center(
                                          child: Text('🏠', style: TextStyle(fontSize: 64)),
                                        ),
                                      ),
                                // Gradient overlay
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Image indicator
                                if (images.length > 1)
                                  Positioned(
                                    bottom: 16,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        images.length,
                                        (i) => Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          width: i == _imageIndex ? 20 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: i == _imageIndex
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Content
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badges
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Badge(
                                      text: _listing!.propertyType.label,
                                      color: context.appColors.primary,
                                    ),
                                    _Badge(
                                      text: _listing!.status.label,
                                      color: _listing!.status == ListingStatus.active
                                          ? context.appColors.success
                                          : _listing!.status == ListingStatus.sold
                                              ? context.appColors.error
                                              : context.appColors.accent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Title
                                Text(
                                  _listing!.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Price
                                if (_listing!.paymentType == PaymentType.installment)
                                  Text(
                                    'Первый взнос',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.appColors.accent,
                                    ),
                                  ),
                                Text(
                                  _formatPrice(_listing!.price),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: context.appColors.primary,
                                  ),
                                ),

                                // Payment Info
                                if (_listing!.paymentType == PaymentType.installment &&
                                    _listing!.installmentMonths != null &&
                                    _listing!.installmentMonthly != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: context.appColors.accent.withValues(alpha: 0.1),
                                      border: Border.all(color: context.appColors.accent.withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('📅', style: TextStyle(fontSize: 16)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Рассрочка',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: context.appColors.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_formatPrice(_listing!.installmentMonthly!)}/мес',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: context.appColors.accent,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'на ${_listing!.installmentMonths} мес. • Итого ${_formatPrice(_listing!.installmentMonths! * _listing!.installmentMonthly!)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.appColors.accent.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '💵 Наличные',
                                    style: TextStyle(fontSize: 14, color: context.appColors.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Address
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: context.appColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _listing!.address,
                                        style: TextStyle(
                                          color: context.appColors.textSecondary,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Features
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.appColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      if (_listing!.rooms != null)
                                        _FeatureItem(
                                          icon: Icons.bed_outlined,
                                          value: '${_listing!.rooms}',
                                          label: 'Комнат',
                                        ),
                                      if (_listing!.area != null)
                                        _FeatureItem(
                                          icon: Icons.square_foot,
                                          value: '${_listing!.area!.toStringAsFixed(0)}',
                                          label: 'м²',
                                        ),
                                      if (_listing!.floor != null)
                                        _FeatureItem(
                                          icon: Icons.stairs,
                                          value: _listing!.totalFloors != null
                                              ? '${_listing!.floor}/${_listing!.totalFloors}'
                                              : '${_listing!.floor}',
                                          label: 'Этаж',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 14, color: context.appColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_listing!.views} просмотров',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.appColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Description
                                const Text(
                                  'Описание',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _listing!.description,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: context.appColors.textSecondary,
                                  ),
                                ),

                                // Map
                                if (hasCoords) ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Расположение',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      height: 200,
                                      child: ListingsMap(
                                        markers: [
                                          MapMarker(
                                            id: _listing!.id,
                                            lat: _listing!.lat!,
                                            lng: _listing!.lng!,
                                            title: _listing!.title,
                                          ),
                                        ],
                                        height: 200,
                                      ),
                                    ),
                                  ),
                                ],

                                // Author
                                if (_listing!.authorName != null) ...[
                                  const SizedBox(height: 24),
                                  GestureDetector(
                                    onTap: () => context.push('/user/${_listing!.authorId}'),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: context.appColors.surfaceWhite,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.appColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                                            child: Text(
                                              _listing!.authorName!.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: context.appColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Продавец',
                                                  style: TextStyle(
                                                    color: context.appColors.textMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  _listing!.authorName!,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (_listing!.authorPhone != null)
                                                  Text(
                                                    _listing!.authorPhone!,
                                                    style: TextStyle(
                                                      color: context.appColors.primary,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (_listing!.authorPhone != null)
                                            IconButton.filled(
                                              onPressed: () {
                                                // Could launch phone call
                                              },
                                              icon: const Icon(Icons.phone),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
      bottomNavigationBar: _listing != null && !_loading
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.surfaceWhite,
                border: Border(top: BorderSide(color: context.appColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? const Color(0xFFE8788A) : null,
                        ),
                        label: Text(_isFavorite ? 'В избранном' : 'В избранное'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    if (!isOwner && auth.isLoggedIn) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final conv = await _chatRepo.createConversation(
                                _listing!.authorId,
                                listingId: _listing!.id,
                              );
                              // Send auto-message with listing context if new conversation
                              if (conv.lastMessage == null) {
                                await _chatRepo.sendMessage(
                                  conv.id,
                                  'Здравствуйте! Интересует объявление: ${_listing!.title}',
                                );
                              }
                              if (mounted) {
                                context.push('/chat/${conv.id}', extra: {
                                  'listingTitle': conv.listingTitle,
                                  'otherUserId': _listing!.authorId,
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
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.appColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}
