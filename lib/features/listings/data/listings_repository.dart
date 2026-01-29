import 'package:real_estate_app/core/api/api_client.dart';
import '../domain/listing.dart';

class ListingsRepository {
  ListingsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<Listing>> getAll() async {
    final list = await _api.get<List<dynamic>>('/listings', (d) => d as List<dynamic>);
    return list.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Listing> getById(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/listings/$id', (d) => d as Map<String, dynamic>);
    return Listing.fromJson(data);
  }

  Future<Listing> create({
    required String title,
    required String description,
    required double price,
    required String address,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/listings',
      {
        'title': title,
        'description': description,
        'price': price,
        'address': address,
      },
      (d) => d as Map<String, dynamic>,
    );
    return Listing.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _api.delete('/listings/$id');
  }
}
