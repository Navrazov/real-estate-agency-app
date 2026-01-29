import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  List<Listing> _listings = [];
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.list;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  ListingsQuery? _buildQuery() {
    final min = double.tryParse(_minPriceCtrl.text);
    final max = double.tryParse(_maxPriceCtrl.text);
    if (min == null && max == null) return null;
    return ListingsQuery(minPrice: min, maxPrice: max);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getAll(query: _buildQuery());
      if (mounted) setState(() => _listings = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final markers = _listings
        .where((l) => l.lat != null && l.lng != null)
        .map((l) => MapMarker(id: l.id, lat: l.lat!, lng: l.lng!, title: l.title))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Недвижимость'),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/create'),
            )
          else
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Войти'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _minPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'От',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('—')),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _maxPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'До',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                Text('₽', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 16),
                SegmentedButton<_ViewMode>(
                  segments: const [
                    ButtonSegment(value: _ViewMode.list, icon: Icon(Icons.list), label: Text('Список')),
                    ButtonSegment(value: _ViewMode.map, icon: Icon(Icons.map), label: Text('Карта')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _listings.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _listings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                          ],
                        ),
                      )
                    : _viewMode == _ViewMode.map
                        ? Column(
                            children: [
                              Expanded(
                                child: ListingsMap(
                                  markers: markers,
                                  selectedId: _selectedId,
                                  onMarkerTap: (id) => setState(() => _selectedId = id),
                                  height: double.infinity,
                                ),
                              ),
                              if (_listings.isNotEmpty)
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: _listings.length,
                                    itemBuilder: (context, i) {
                                      final l = _listings[i];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: InkWell(
                                          onTap: () => context.push('/listing/${l.id}'),
                                          child: Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: SizedBox(
                                                width: 160,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (l.images.isNotEmpty)
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: Image.network(
                                                          l.images.first,
                                                          height: 50,
                                                          width: double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      )
                                                    else
                                                      const SizedBox(height: 50, child: Center(child: Text('Нет фото'))),
                                                    const SizedBox(height: 4),
                                                    Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    Text('${l.price.toStringAsFixed(0)} ₽', style: Theme.of(context).textTheme.titleSmall),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          )
                        : _listings.isEmpty
                            ? const Center(child: Text('Пока нет объявлений'))
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _listings.length,
                                  itemBuilder: (context, i) {
                                    final l = _listings[i];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: l.images.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(l.images.first, width: 56, height: 56, fit: BoxFit.cover),
                                              )
                                            : const SizedBox(width: 56, height: 56, child: Icon(Icons.home)),
                                        title: Text(l.title),
                                        subtitle: Text(l.address),
                                        trailing: Text(
                                          '${l.price.toStringAsFixed(0)} ₽',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        onTap: () => context.push('/listing/${l.id}'),
                                      ),
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
