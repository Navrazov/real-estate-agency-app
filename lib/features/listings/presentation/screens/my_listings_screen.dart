import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:real_estate_app/core/widgets/skeleton.dart';
import 'package:real_estate_app/features/listings/data/listings_repository.dart';
import 'package:real_estate_app/features/listings/domain/listing.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _repo = ListingsRepository();
  List<Listing> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await _repo.getMy();
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

  void _showActions(Listing listing) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/listing/${listing.id}/edit');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.appColors.error),
              title: Text('Удалить', style: TextStyle(color: context.appColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteListing(listing.id);
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

  Future<void> _deleteListing(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: TextStyle(color: context.appColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.delete(id);
        setState(() {
          _listings.removeWhere((l) => l.id == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Объявление удалено')),
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
        title: const Text('Мои объявления'),
      ),
      body: _loading
          ? const SkeletonMyListings()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: context.appColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadListings,
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
                          const Text('📝', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          const Text(
                            'Нет объявлений',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Вы ещё не разместили ни одного объявления',
                            style: TextStyle(color: context.appColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/create'),
                            icon: const Icon(Icons.add),
                            label: const Text('Создать'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadListings,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          return _MyListingCompactCard(
                            listing: listing,
                            onTap: () => context.push('/listing/${listing.id}'),
                            onLongPress: () => _showActions(listing),
                            formatPrice: _formatPrice,
                          );
                        },
                      ),
                    ),
      floatingActionButton: _listings.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/create'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _MyListingCompactCard extends StatelessWidget {
  const _MyListingCompactCard({
    required this.listing,
    required this.onTap,
    required this.onLongPress,
    required this.formatPrice,
  });

  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: listing.images.isNotEmpty
                      ? Image.network(
                          listing.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: context.appColors.surface,
                            child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                          ),
                        )
                      : Container(
                          color: context.appColors.surface,
                          child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                        ),
                ),
                // Status badge
                if (listing.moderationStatus == ModerationStatus.pending ||
                    listing.moderationStatus == ModerationStatus.rejected ||
                    (listing.moderationStatus == ModerationStatus.approved &&
                        listing.status != ListingStatus.active))
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusText(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                // Views badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 11, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${listing.views}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
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

  String _statusText() {
    if (listing.moderationStatus == ModerationStatus.pending) return 'На модерации';
    if (listing.moderationStatus == ModerationStatus.rejected) return 'Отклонено';
    return listing.status.label;
  }

  Color _statusColor(BuildContext context) {
    if (listing.moderationStatus == ModerationStatus.pending) return context.appColors.accent;
    if (listing.moderationStatus == ModerationStatus.rejected) return context.appColors.error;
    if (listing.status == ListingStatus.sold) return context.appColors.error;
    return context.appColors.accent;
  }
}
