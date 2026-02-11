import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/widgets/listings_map.dart';
import '../../data/listings_repository.dart';
import '../../domain/listing.dart';

enum _ViewMode { list, map }

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _repo = ListingsRepository();
  ListingsResponse? _response;
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.list;
  String? _selectedId;
  bool _showFilters = false;

  // Filters
  final _searchCtrl = TextEditingController();
  PropertyType? _propertyType;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  String _sortBy = 'date';
  String _sortOrder = 'desc';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  ListingsQuery _buildQuery() {
    return ListingsQuery(
      search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      propertyType: _propertyType,
      minPrice: double.tryParse(_minPriceCtrl.text),
      maxPrice: double.tryParse(_maxPriceCtrl.text),
      sortBy: _sortBy,
      sortOrder: _sortOrder,
      page: _page,
      limit: 20,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repo.getAll(query: _buildQuery());
      if (mounted) setState(() => _response = response);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _page = 1;
    _load();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _propertyType = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _sortBy = 'date';
      _sortOrder = 'desc';
      _page = 1;
    });
    _load();
  }

  Future<void> _toggleFavorite(Listing listing) async {
    final auth = AuthServiceScope.of(context);
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    try {
      final result = await _repo.toggleFavorite(listing.id);
      final favorites = (result['favorites'] as List<dynamic>).cast<String>();
      auth.updateFavorites(favorites);
      setState(() {
        final index = _response!.items.indexWhere((l) => l.id == listing.id);
        if (index >= 0) {
          _response!.items[index] = listing.copyWith(isFavorite: result['isFavorite'] as bool);
        }
      });
    } catch (e) {
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
    final auth = AuthServiceScope.of(context);
    final listings = _response?.items ?? [];
    final markers = listings
        .where((l) => l.lat != null && l.lng != null)
        .map((l) => MapMarker(id: l.id, lat: l.lat!, lng: l.lng!, title: l.title))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('EstateHub'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Поиск',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onSubmitted: (_) => _applyFilters(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: IconButton.filled(
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                        icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: _showFilters
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.1),
                          foregroundColor: _showFilters ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<_ViewMode>(
                      segments: const [
                        ButtonSegment(value: _ViewMode.list, icon: Icon(Icons.view_list, size: 18)),
                        ButtonSegment(value: _ViewMode.map, icon: Icon(Icons.map, size: 18)),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                      showSelectedIcon: false,
                    ),
                  ],
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  _buildFiltersPanel(),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading && listings.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && listings.isEmpty
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
                    : _viewMode == _ViewMode.map
                        ? _buildMapView(markers, listings)
                        : listings.isEmpty
                            ? _buildEmptyState()
                            : _buildGridView(listings, auth),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Column(
      children: [
        // Property Type
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Все',
                selected: _propertyType == null,
                onTap: () {
                  setState(() => _propertyType = null);
                  _applyFilters();
                },
              ),
              ...PropertyType.values.map((type) => _FilterChip(
                    label: '${type.icon} ${type.label}',
                    selected: _propertyType == type,
                    onTap: () {
                      setState(() => _propertyType = type);
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minPriceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Цена от',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxPriceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Цена до',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Сортировка:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SortChip(
                      label: 'По дате',
                      selected: _sortBy == 'date',
                      ascending: _sortOrder == 'asc',
                      onTap: () {
                        setState(() {
                          if (_sortBy == 'date') {
                            _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                          } else {
                            _sortBy = 'date';
                            _sortOrder = 'desc';
                          }
                        });
                        _applyFilters();
                      },
                    ),
                    _SortChip(
                      label: 'По цене',
                      selected: _sortBy == 'price',
                      ascending: _sortOrder == 'asc',
                      onTap: () {
                        setState(() {
                          if (_sortBy == 'price') {
                            _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                          } else {
                            _sortBy = 'price';
                            _sortOrder = 'desc';
                          }
                        });
                        _applyFilters();
                      },
                    ),
                    _SortChip(
                      label: 'По просмотрам',
                      selected: _sortBy == 'views',
                      ascending: _sortOrder == 'asc',
                      onTap: () {
                        setState(() {
                          if (_sortBy == 'views') {
                            _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                          } else {
                            _sortBy = 'views';
                            _sortOrder = 'desc';
                          }
                        });
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Сбросить'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridView(List<Listing> listings, AuthService auth) {
    final hasMore = _response != null && _response!.page < _response!.totalPages;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final l = listings[i];
                  return _CompactListingCard(
                    listing: l,
                    onTap: () => context.push('/listing/${l.id}'),
                    onFavorite: () => _toggleFavorite(l),
                    formatPrice: _formatPrice,
                    isLoggedIn: auth.isLoggedIn,
                  );
                },
                childCount: listings.length,
              ),
            ),
          ),
          if (hasMore)
            SliverToBoxAdapter(
              child: Padding(
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapView(List<MapMarker> markers, List<Listing> listings) {
    return Column(
      children: [
        Expanded(
          child: ListingsMap(
            markers: markers,
            selectedId: _selectedId,
            onMarkerTap: (id) => setState(() => _selectedId = id),
            height: double.infinity,
          ),
        ),
        if (listings.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: listings.length,
              itemBuilder: (context, i) {
                final l = listings[i];
                final isSelected = l.id == _selectedId;
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    elevation: isSelected ? 4 : 0,
                    color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                    child: InkWell(
                      onTap: () => context.push('/listing/${l.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: l.images.isNotEmpty
                                  ? Image.network(
                                      l.images.first,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: AppColors.surface,
                                      child: const Center(child: Text('🏠')),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatPrice(l.price),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Объявлений не найдено',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Попробуйте изменить параметры поиска',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _clearFilters,
            child: const Text('Сбросить фильтры'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: selected
            ? Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: AppColors.primary,
              )
            : null,
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected ? AppColors.primary.withOpacity(0.1) : null,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}

/// Compact card for the 2-column grid, Avito-style.
class _CompactListingCard extends StatelessWidget {
  const _CompactListingCard({
    required this.listing,
    required this.onTap,
    required this.onFavorite,
    required this.formatPrice,
    required this.isLoggedIn,
  });

  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final String Function(double) formatPrice;
  final bool isLoggedIn;

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
            // Image with aspect ratio 4:3
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: listing.images.isNotEmpty
                      ? Image.network(
                          listing.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface,
                            child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                          ),
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Center(child: Text('🏠', style: TextStyle(fontSize: 32))),
                        ),
                ),
                // Favorite button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        listing.isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: listing.isFavorite ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Compact info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Text(
                      formatPrice(listing.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Title
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
                    // Rooms / Area inline
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    // Address
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.address,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
}
