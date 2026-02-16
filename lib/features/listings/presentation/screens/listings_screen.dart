import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/widgets/listings_map.dart';
import '../../../../core/widgets/skeleton.dart';
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
  ApartmentType? _apartmentType;
  PaymentType? _paymentType;
  String? _developer;
  String? _complex;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _minRoomsCtrl = TextEditingController();
  final _maxRoomsCtrl = TextEditingController();
  final _minAreaCtrl = TextEditingController();
  final _maxAreaCtrl = TextEditingController();
  String _sortBy = 'date';
  String _sortOrder = 'desc';
  int _page = 1;
  FilterOptions _filterOptions = FilterOptions(developers: [], complexes: []);

  @override
  void initState() {
    super.initState();
    _load();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await _repo.getFilterOptions();
      if (mounted) setState(() => _filterOptions = options);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minRoomsCtrl.dispose();
    _maxRoomsCtrl.dispose();
    _minAreaCtrl.dispose();
    _maxAreaCtrl.dispose();
    super.dispose();
  }

  ListingsQuery _buildQuery() {
    return ListingsQuery(
      search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      propertyType: _propertyType,
      apartmentType: _propertyType == PropertyType.apartment ? _apartmentType : null,
      paymentType: _paymentType,
      developer: _developer,
      complex: _complex,
      minPrice: double.tryParse(_minPriceCtrl.text),
      maxPrice: double.tryParse(_maxPriceCtrl.text),
      minRooms: int.tryParse(_minRoomsCtrl.text),
      maxRooms: int.tryParse(_maxRoomsCtrl.text),
      minArea: double.tryParse(_minAreaCtrl.text),
      maxArea: double.tryParse(_maxAreaCtrl.text),
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
      _apartmentType = null;
      _paymentType = null;
      _developer = null;
      _complex = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _minRoomsCtrl.clear();
      _maxRoomsCtrl.clear();
      _minAreaCtrl.clear();
      _maxAreaCtrl.clear();
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_rounded, color: context.appColors.primary),
            const SizedBox(width: 8),
            const Text('EstateHub'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: context.appColors.border)),
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
                              ? context.appColors.primary
                              : context.appColors.primary.withValues(alpha: 0.1),
                          foregroundColor: _showFilters ? Colors.white : context.appColors.primary,
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
                ? const SkeletonListingsGrid()
                : _error != null && listings.isEmpty
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
                    : _loading && _response != null
                        ? const SkeletonListingsGrid()
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
                  setState(() {
                    _propertyType = null;
                    _apartmentType = null;
                  });
                  _applyFilters();
                },
              ),
              ...PropertyType.values.map((type) => _FilterChip(
                    label: '${type.icon} ${type.label}',
                    selected: _propertyType == type,
                    onTap: () {
                      setState(() {
                        _propertyType = type;
                        if (type != PropertyType.apartment) _apartmentType = null;
                      });
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),

        // Apartment Type (only when apartment selected)
        if (_propertyType == PropertyType.apartment) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Любой',
                  selected: _apartmentType == null,
                  onTap: () {
                    setState(() => _apartmentType = null);
                    _applyFilters();
                  },
                ),
                ...ApartmentType.values.map((type) => _FilterChip(
                      label: '${type.icon} ${type.label}',
                      selected: _apartmentType == type,
                      onTap: () {
                        setState(() => _apartmentType = type);
                        _applyFilters();
                      },
                    )),
              ],
            ),
          ),
        ],

        // Payment Type
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('Оплата:', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
              ),
              _FilterChip(
                label: 'Любая',
                selected: _paymentType == null,
                onTap: () {
                  setState(() => _paymentType = null);
                  _applyFilters();
                },
              ),
              ...PaymentType.values.map((type) => _FilterChip(
                    label: '${type.icon} ${type.label}',
                    selected: _paymentType == type,
                    onTap: () {
                      setState(() => _paymentType = type);
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),

        // Developer & Complex dropdowns
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('dev_$_developer'),
                initialValue: _developer,
                decoration: const InputDecoration(
                  labelText: 'Застройщик',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ..._filterOptions.developers.map((d) =>
                    DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
                  ),
                ],
                onChanged: _filterOptions.developers.isEmpty ? null : (v) {
                  setState(() => _developer = v);
                  _applyFilters();
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('cpx_$_complex'),
                initialValue: _complex,
                decoration: const InputDecoration(
                  labelText: 'ЖК',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ..._filterOptions.complexes.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                  ),
                ],
                onChanged: _filterOptions.complexes.isEmpty ? null : (v) {
                  setState(() => _complex = v);
                  _applyFilters();
                },
                isExpanded: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Price
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minPriceCtrl,
                decoration: InputDecoration(
                  labelText: _paymentType == PaymentType.installment ? 'Первый взнос от' : 'Цена от',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxPriceCtrl,
                decoration: InputDecoration(
                  labelText: _paymentType == PaymentType.installment ? 'Первый взнос до' : 'Цена до',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Rooms & Area
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minRoomsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Комнат от',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _maxRoomsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Комнат до',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _minAreaCtrl,
                decoration: const InputDecoration(
                  labelText: 'м² от',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _maxAreaCtrl,
                decoration: const InputDecoration(
                  labelText: 'м² до',
                  isDense: true,
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
            Text('Сортировка:', style: TextStyle(color: context.appColors.textSecondary)),
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

  List<Widget> _buildPageButtons() {
    final total = _response!.totalPages;
    final current = _page;

    int start = (current - 2).clamp(1, total);
    int end = (current + 2).clamp(1, total);

    // Ensure we show at least 5 buttons if possible
    if (end - start < 4) {
      if (start == 1) {
        end = (start + 4).clamp(1, total);
      } else if (end == total) {
        start = (end - 4).clamp(1, total);
      }
    }

    final buttons = <Widget>[];

    if (start > 1) {
      buttons.add(_PageButton(page: 1, current: current, onTap: () {
        setState(() => _page = 1);
        _load();
      }));
      if (start > 2) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...'),
        ));
      }
    }

    for (int i = start; i <= end; i++) {
      buttons.add(_PageButton(page: i, current: current, onTap: () {
        setState(() => _page = i);
        _load();
      }));
    }

    if (end < total) {
      if (end < total - 1) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...'),
        ));
      }
      buttons.add(_PageButton(page: total, current: current, onTap: () {
        setState(() => _page = total);
        _load();
      }));
    }

    return buttons;
  }

  Widget _buildGridView(List<Listing> listings, AuthService auth) {
    final totalActive = _response?.totalActive;
    final hiddenCount = (totalActive != null && totalActive > listings.length)
        ? (totalActive - listings.length).clamp(0, 7)
        : 0;
    final totalGridItems = listings.length + hiddenCount;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i < listings.length) {
                    final l = listings[i];
                    return _CompactListingCard(
                      listing: l,
                      onTap: () => context.push('/listing/${l.id}'),
                      onFavorite: () => _toggleFavorite(l),
                      formatPrice: _formatPrice,
                      isLoggedIn: auth.isLoggedIn,
                    );
                  }
                  // Skeleton card for hidden listings
                  return _SkeletonListingCard();
                },
                childCount: totalGridItems,
              ),
            ),
          ),
          // Subscription CTA banner for free users
          if (totalActive != null && totalActive > listings.length)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.appColors.primary.withValues(alpha: 0.08),
                      Colors.blue.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Доступно $totalActive ${_pluralize(totalActive, 'объявление', 'объявления', 'объявлений')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Вы видите ${listings.length} из $totalActive. Оформите подписку, чтобы видеть все.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_response != null && _response!.totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _page > 1
                          ? () {
                              setState(() => _page--);
                              _load();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      visualDensity: VisualDensity.compact,
                    ),
                    ..._buildPageButtons(),
                    IconButton(
                      onPressed: _page < _response!.totalPages
                          ? () {
                              setState(() => _page++);
                              _load();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
                    color: isSelected ? context.appColors.primary.withValues(alpha: 0.05) : null,
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
                                  ? CachedNetworkImage(
                                      imageUrl: l.images.first,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 60, height: 60,
                                        color: context.appColors.surface,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 60, height: 60,
                                        color: context.appColors.surface,
                                        child: const Center(child: Text('🏠')),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: context.appColors.surface,
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
                                  if (l.paymentType == PaymentType.installment)
                                    Text(
                                      'Первый взнос',
                                      style: TextStyle(fontSize: 10, color: context.appColors.accent, fontWeight: FontWeight.w600),
                                    ),
                                  Text(
                                    _formatPrice(l.price),
                                    style: TextStyle(
                                      color: context.appColors.primary,
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
          Text(
            'Попробуйте изменить параметры поиска',
            style: TextStyle(color: context.appColors.textSecondary),
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
        selectedColor: context.appColors.primary.withValues(alpha: 0.2),
        checkmarkColor: context.appColors.primary,
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
                color: context.appColors.primary,
              )
            : null,
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected ? context.appColors.primary.withValues(alpha: 0.1) : null,
        side: BorderSide(
          color: selected ? context.appColors.primary : context.appColors.border,
        ),
      ),
    );
  }
}

/// Compact card for the 2-column grid, Avito-style.
class _CompactListingCard extends StatelessWidget {
  const _CompactListingCard({
    required this.listing,
    this.onTap,
    this.onFavorite,
    required this.formatPrice,
    required this.isLoggedIn,
  });

  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final String Function(double) formatPrice;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final imageWidget = listing.images.isNotEmpty
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
          );

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with Hero animation
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Hero(
                          tag: 'listing-image-${listing.id}',
                          child: imageWidget,
                        ),
                      ),
                      // Favorite button
                      if (isLoggedIn)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: onFavorite,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceWhite.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                listing.isFavorite ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: listing.isFavorite ? const Color(0xFFE8788A) : context.appColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Compact info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price
                        if (listing.paymentType == PaymentType.installment)
                          Text(
                            'Первый взнос',
                            style: TextStyle(fontSize: 10, color: context.appColors.accent, fontWeight: FontWeight.w600),
                          ),
                        Text(
                          formatPrice(listing.price),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Title
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Rooms / Area inline
                        if (listing.rooms != null || listing.area != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              [
                                if (listing.rooms != null) '${listing.rooms} комн.',
                                if (listing.area != null) '${listing.area!.toStringAsFixed(0)} м\u00B2',
                                if (listing.floor != null)
                                  listing.totalFloors != null
                                      ? '${listing.floor}/${listing.totalFloors} эт.'
                                      : '${listing.floor} эт.',
                              ].join(' \u00B7 '),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // Address
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _SkeletonListingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(color: context.appColors.surface),
              ),
              // Text placeholders
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 80, decoration: BoxDecoration(color: context.appColors.surface, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: context.appColors.surface, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(height: 12, width: 100, decoration: BoxDecoration(color: context.appColors.surface, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: context.appColors.surfaceWhite.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(Icons.lock_outline, size: 24, color: context.appColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.current,
    required this.onTap,
  });

  final int page;
  final int current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = page == current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: isActive ? context.appColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: isActive ? null : onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                '$page',
                style: TextStyle(
                  color: isActive ? Colors.white : context.appColors.textPrimary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
