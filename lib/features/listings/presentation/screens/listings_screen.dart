import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../data/listings_repository.dart';
import '../../domain/listing.dart';
import 'listing_detail_screen.dart';

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
      final list = await _repo.getAll();
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
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
    );
  }
}
