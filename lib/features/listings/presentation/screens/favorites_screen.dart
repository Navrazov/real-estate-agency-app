import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/widgets/skeleton.dart';
import 'package:real_estate_app/features/listings/data/listings_repository.dart';
import 'package:real_estate_app/features/listings/domain/listing.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = ListingsRepository();
  List<Listing> _listings = [];
  final Set<String> _removedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
      _removedIds.clear();
    });
    try {
      final listings = await _repo.getFavorites();
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(String listingId) async {
    final wasRemoved = _removedIds.contains(listingId);
    setState(() {
      if (wasRemoved) {
        _removedIds.remove(listingId);
      } else {
        _removedIds.add(listingId);
      }
    });
    try {
      final result = await _repo.toggleFavorite(listingId);
      final favorites = (result['favorites'] as List<dynamic>).cast<String>();
      if (mounted) {
        AuthServiceScope.of(context).updateFavorites(favorites);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasRemoved) {
          _removedIds.add(listingId);
        } else {
          _removedIds.remove(listingId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: _loading
          ? const SkeletonFavoritesList()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: context.appColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFavorites,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _listings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💜', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          const Text(
                            'Нет избранного',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавляйте понравившиеся объекты',
                            style: TextStyle(color: context.appColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.go('/'),
                            child: const Text('К каталогу'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          final isRemoved = _removedIds.contains(listing.id);
                          return _FavoriteCompactCard(
                            listing: listing,
                            isRemoved: isRemoved,
                            onTap: () => context.push('/listing/${listing.id}'),
                            onFavorite: () => _toggleFavorite(listing.id),
                            formatPrice: _formatPrice,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _FavoriteCompactCard extends StatelessWidget {
  const _FavoriteCompactCard({
    required this.listing,
    required this.isRemoved,
    required this.onTap,
    required this.onFavorite,
    required this.formatPrice,
  });

  final Listing listing;
  final bool isRemoved;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
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
                            child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                          ),
                        )
                      : Container(
                          color: context.appColors.surface,
                          child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRemoved ? Icons.favorite_border : Icons.favorite,
                        size: 16,
                        color: isRemoved ? context.appColors.textMuted : const Color(0xFFE8788A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (listing.paymentType == PaymentType.installment)
                      Text(
                        'Первый взнос',
                        style: TextStyle(fontSize: 10, color: context.appColors.accent, fontWeight: FontWeight.w600),
                      ),
                    Text(
                      formatPrice(listing.price),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.appColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (listing.rooms != null || listing.area != null)
                      Text(
                        [
                          if (listing.rooms != null) '${listing.rooms} комн.',
                          if (listing.area != null) '${listing.area!.toStringAsFixed(0)} м\u00B2',
                          if (listing.floor != null)
                            listing.totalFloors != null
                                ? '${listing.floor}/${listing.totalFloors} эт.'
                                : '${listing.floor} эт.',
                        ].join(' \u00B7 '),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: context.appColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.address,
                            style: TextStyle(
                              color: context.appColors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(listing.createdAt),
                          style: TextStyle(
                            color: context.appColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    if (diff < 7) return '$diff дн.';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${d.day} ${months[d.month - 1]}';
  }
}
