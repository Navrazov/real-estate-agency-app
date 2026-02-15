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
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          return _ListingCard(
                            listing: listing,
                            onTap: () => context.push('/listing/${listing.id}'),
                            onEdit: () => context.push('/listing/${listing.id}/edit'),
                            onDelete: () => _deleteListing(listing.id),
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

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.formatPrice,
  });

  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                SizedBox(
                  width: 120,
                  height: 120,
                  child: listing.images.isNotEmpty
                      ? Image.network(
                          listing.images.first,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: context.appColors.surface,
                          child: const Center(
                            child: Text('🏠', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges
                        Wrap(
                          spacing: 8,
                          children: [
                            _Badge(
                              text: listing.propertyType.label,
                              color: context.appColors.primary,
                            ),
                            if (listing.moderationStatus == ModerationStatus.pending)
                              _Badge(
                                text: 'На модерации',
                                color: Colors.orange,
                              ),
                            if (listing.moderationStatus == ModerationStatus.rejected)
                              _Badge(
                                text: 'Отклонено',
                                color: context.appColors.error,
                              ),
                            if (listing.moderationStatus == ModerationStatus.approved &&
                                listing.status != ListingStatus.active)
                              _Badge(
                                text: listing.status.label,
                                color: listing.status == ListingStatus.sold
                                    ? context.appColors.error
                                    : context.appColors.accent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (listing.paymentType == PaymentType.installment)
                          Text(
                            'Первый взнос',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                          ),
                        Text(
                          formatPrice(listing.price),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.appColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: context.appColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${listing.views}',
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 12,
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Редактировать'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 18, color: context.appColors.error),
                      label: Text('Удалить', style: TextStyle(color: context.appColors.error)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
