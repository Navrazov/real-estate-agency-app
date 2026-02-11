import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/widgets/listings_map.dart';
import '../../../chat/data/chat_repository.dart';
import '../../data/listings_repository.dart';
import '../../domain/listing.dart';

enum _ViewMode { list, map }

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

enum _UserMenuAction { create, logout }

class _ListingsScreenState extends State<ListingsScreen> {
  final _repo = ListingsRepository();
  final _chatRepo = ChatRepository();
  final _socketService = SocketService();
  ListingsResponse? _response;
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.list;
  String? _selectedId;
  bool _showFilters = false;
  int _unreadMessages = 0;
  Timer? _unreadTimer;

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
    _loadUnreadCount();
    _setupSocket();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    // Instant unread count update from server
    _socketService.on('unread_count', (data) {
      if (!mounted) return;
      final count = (data as Map<String, dynamic>)['count'] as int? ?? 0;
      setState(() => _unreadMessages = count);
    });
    // Also refresh on new_message as fallback
    _socketService.on('new_message', (_) {
      if (mounted) _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _socketService.off('unread_count');
    _socketService.off('new_message');
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final auth = AuthServiceScope.of(context);
    if (!auth.isLoggedIn) return;
    try {
      final count = await _chatRepo.getUnreadCount();
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {}
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
        actions: [
          if (auth.isLoggedIn) ...[
            IconButton(
              icon: Badge(
                isLabelVisible: _unreadMessages > 0,
                label: Text(
                  _unreadMessages > 99 ? '99+' : '$_unreadMessages',
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              onPressed: () async {
                await context.push('/conversations');
                if (mounted) _loadUnreadCount();
              },
              tooltip: 'Сообщения',
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () => context.push('/favorites'),
              tooltip: 'Избранное',
            ),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () => context.push('/my'),
              tooltip: 'Мои объявления',
            ),
            PopupMenuButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  auth.user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onSelected: (action) {
                switch (action) {
                  case _UserMenuAction.create:
                    context.push('/create');
                    break;
                  case _UserMenuAction.logout:
                    auth.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вы вышли из аккаунта')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<_UserMenuAction>>[
                PopupMenuItem<_UserMenuAction>(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(auth.user?.displayName ?? 'User'),
                    subtitle: Text(
                      auth.user?.email ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  enabled: false,
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<_UserMenuAction>(
                  value: _UserMenuAction.create,
                  child: const ListTile(
                    leading: Icon(Icons.add_circle_outline),
                    title: Text('Добавить объявление'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem<_UserMenuAction>(
                  value: _UserMenuAction.logout,
                  child: const ListTile(
                    leading: Icon(Icons.logout, color: AppColors.error),
                    title: Text('Выйти', style: TextStyle(color: AppColors.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ] else
            TextButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Войти'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию или адресу',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                      icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                      style: IconButton.styleFrom(
                        backgroundColor: _showFilters
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.1),
                        foregroundColor: _showFilters ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<_ViewMode>(
                      segments: const [
                        ButtonSegment(value: _ViewMode.list, icon: Icon(Icons.view_list)),
                        ButtonSegment(value: _ViewMode.map, icon: Icon(Icons.map)),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                      showSelectedIcon: false,
                    ),
                  ],
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 16),
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
                            : _buildListView(listings, auth),
          ),
        ],
      ),
      floatingActionButton: auth.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/create'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
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

  Widget _buildListView(List<Listing> listings, AuthService auth) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: listings.length + (_response != null && _response!.page < _response!.totalPages ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= listings.length) {
            return Padding(
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
            );
          }
          final l = listings[i];
          return _ListingCard(
            listing: l,
            onTap: () => context.push('/listing/${l.id}'),
            onFavorite: () => _toggleFavorite(l),
            formatPrice: _formatPrice,
            isLoggedIn: auth.isLoggedIn,
          );
        },
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

class _ListingCard extends StatelessWidget {
  const _ListingCard({
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
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: listing.images.isNotEmpty
                      ? Image.network(
                          listing.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface,
                            child: const Center(child: Text('🏠', style: TextStyle(fontSize: 48))),
                          ),
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Center(child: Text('🏠', style: TextStyle(fontSize: 48))),
                        ),
                ),
                // Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _Badge(text: listing.propertyType.label, color: AppColors.primary),
                      if (listing.status != ListingStatus.active)
                        _Badge(
                          text: listing.status.label,
                          color: listing.status == ListingStatus.sold
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                    ],
                  ),
                ),
                // Favorite
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        listing.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: listing.isFavorite ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                // Views
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${listing.views}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatPrice(listing.price),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (listing.paymentType == PaymentType.installment && listing.installmentMonthly != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '📅 ${formatPrice(listing.installmentMonthly!)}/мес',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber.shade700),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.address,
                          style: const TextStyle(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Features
                  Wrap(
                    spacing: 16,
                    children: [
                      if (listing.rooms != null)
                        _Feature(icon: Icons.bed_outlined, text: '${listing.rooms} комн.'),
                      if (listing.area != null)
                        _Feature(icon: Icons.square_foot, text: '${listing.area!.toStringAsFixed(0)} м²'),
                      if (listing.floor != null)
                        _Feature(
                          icon: Icons.stairs,
                          text: listing.totalFloors != null
                              ? '${listing.floor}/${listing.totalFloors} эт.'
                              : '${listing.floor} эт.',
                        ),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
