import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:real_estate_app/core/api/api_client.dart';
import '../domain/listing.dart';

class ListingsQuery {
  final double? minPrice;
  final double? maxPrice;
  final double? swLat;
  final double? swLng;
  final double? neLat;
  final double? neLng;
  ListingsQuery({this.minPrice, this.maxPrice, this.swLat, this.swLng, this.neLat, this.neLng});
  Map<String, String> toParams() {
    final m = <String, String>{};
    if (minPrice != null) m['minPrice'] = minPrice!.toString();
    if (maxPrice != null) m['maxPrice'] = maxPrice!.toString();
    if (swLat != null) m['swLat'] = swLat!.toString();
    if (swLng != null) m['swLng'] = swLng!.toString();
    if (neLat != null) m['neLat'] = neLat!.toString();
    if (neLng != null) m['neLng'] = neLng!.toString();
    return m;
  }
}

class ListingsRepository {
  ListingsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<Listing>> getAll({ListingsQuery? query}) async {
    final params = query?.toParams();
    final list = await _api.get<List<dynamic>>(
      '/listings',
      (d) => d as List<dynamic>,
      queryParams: params?.isNotEmpty == true ? params : null,
    );
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
    List<String>? images,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'price': price,
      'address': address,
    };
    if (images != null && images.isNotEmpty) body['images'] = images;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    final data = await _api.post<Map<String, dynamic>>('/listings', body, (d) => d as Map<String, dynamic>);
    return Listing.fromJson(data);
  }

  Future<List<String>> uploadImages(List<File> files) async {
    final multipart = <http.MultipartFile>[];
    for (final f in files) {
      multipart.add(await http.MultipartFile.fromPath('images', f.path));
    }
    return _api.uploadImages(multipart);
  }

  Future<void> delete(String id) async {
    await _api.delete('/listings/$id');
  }
}
