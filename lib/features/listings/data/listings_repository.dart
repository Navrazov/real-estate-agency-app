import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:real_estate_app/core/api/api_client.dart';
import '../domain/listing.dart';

class ListingsQuery {
  final String? search;
  final PropertyType? propertyType;
  final ListingStatus? status;
  final double? minPrice;
  final double? maxPrice;
  final int? minRooms;
  final int? maxRooms;
  final double? minArea;
  final double? maxArea;
  final String? sortBy;
  final String? sortOrder;
  final int? page;
  final int? limit;
  final double? swLat;
  final double? swLng;
  final double? neLat;
  final double? neLng;

  ListingsQuery({
    this.search,
    this.propertyType,
    this.status,
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.maxRooms,
    this.minArea,
    this.maxArea,
    this.sortBy,
    this.sortOrder,
    this.page,
    this.limit,
    this.swLat,
    this.swLng,
    this.neLat,
    this.neLng,
  });

  Map<String, String> toParams() {
    final m = <String, String>{};
    if (search != null && search!.isNotEmpty) m['search'] = search!;
    if (propertyType != null) {
      m['propertyType'] = propertyType.toString().split('.').last;
    }
    if (status != null) {
      m['status'] = status.toString().split('.').last;
    }
    if (minPrice != null) m['minPrice'] = minPrice!.toString();
    if (maxPrice != null) m['maxPrice'] = maxPrice!.toString();
    if (minRooms != null) m['minRooms'] = minRooms!.toString();
    if (maxRooms != null) m['maxRooms'] = maxRooms!.toString();
    if (minArea != null) m['minArea'] = minArea!.toString();
    if (maxArea != null) m['maxArea'] = maxArea!.toString();
    if (sortBy != null) m['sortBy'] = sortBy!;
    if (sortOrder != null) m['sortOrder'] = sortOrder!;
    if (page != null) m['page'] = page!.toString();
    if (limit != null) m['limit'] = limit!.toString();
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

  Future<ListingsResponse> getAll({ListingsQuery? query}) async {
    final params = query?.toParams();
    final data = await _api.get<Map<String, dynamic>>(
      '/listings',
      (d) => d as Map<String, dynamic>,
      queryParams: params?.isNotEmpty == true ? params : null,
    );
    return ListingsResponse.fromJson(data);
  }

  Future<List<Listing>> getMy() async {
    final list = await _api.get<List<dynamic>>(
      '/listings/my',
      (d) => d as List<dynamic>,
    );
    return list.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Listing> getById(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/listings/$id',
      (d) => d as Map<String, dynamic>,
    );
    return Listing.fromJson(data);
  }

  Future<Listing> create({
    required String title,
    required String description,
    required double price,
    PaymentType? paymentType,
    int? installmentMonths,
    double? installmentMonthly,
    required String address,
    PropertyType? propertyType,
    int? rooms,
    double? area,
    int? floor,
    int? totalFloors,
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
    if (paymentType != null) {
      body['paymentType'] = paymentType.toString().split('.').last;
    }
    if (installmentMonths != null) body['installmentMonths'] = installmentMonths;
    if (installmentMonthly != null) body['installmentMonthly'] = installmentMonthly;
    if (propertyType != null) {
      body['propertyType'] = propertyType.toString().split('.').last;
    }
    if (rooms != null) body['rooms'] = rooms;
    if (area != null) body['area'] = area;
    if (floor != null) body['floor'] = floor;
    if (totalFloors != null) body['totalFloors'] = totalFloors;
    if (images != null && images.isNotEmpty) body['images'] = images;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    final data = await _api.post<Map<String, dynamic>>(
      '/listings',
      body,
      (d) => d as Map<String, dynamic>,
    );
    return Listing.fromJson(data);
  }

  Future<Listing> update(
    String id, {
    String? title,
    String? description,
    double? price,
    PaymentType? paymentType,
    int? installmentMonths,
    double? installmentMonthly,
    String? address,
    PropertyType? propertyType,
    ListingStatus? status,
    int? rooms,
    double? area,
    int? floor,
    int? totalFloors,
    List<String>? images,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (paymentType != null) {
      body['paymentType'] = paymentType.toString().split('.').last;
    }
    if (installmentMonths != null) body['installmentMonths'] = installmentMonths;
    if (installmentMonthly != null) body['installmentMonthly'] = installmentMonthly;
    if (address != null) body['address'] = address;
    if (propertyType != null) {
      body['propertyType'] = propertyType.toString().split('.').last;
    }
    if (status != null) {
      body['status'] = status.toString().split('.').last;
    }
    if (rooms != null) body['rooms'] = rooms;
    if (area != null) body['area'] = area;
    if (floor != null) body['floor'] = floor;
    if (totalFloors != null) body['totalFloors'] = totalFloors;
    if (images != null) body['images'] = images;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    final data = await _api.patch<Map<String, dynamic>>(
      '/listings/$id',
      body,
      (d) => d as Map<String, dynamic>,
    );
    return Listing.fromJson(data);
  }

  Future<List<String>> uploadImages(List<XFile> files) async {
    final multipart = <http.MultipartFile>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final filename = f.name;
      multipart.add(http.MultipartFile.fromBytes('images', bytes, filename: filename));
    }
    return _api.uploadImages(multipart);
  }

  Future<void> delete(String id) async {
    await _api.delete('/listings/$id');
  }

  // Favorites
  Future<List<Listing>> getFavorites() async {
    final list = await _api.get<List<dynamic>>(
      '/users/favorites',
      (d) => d as List<dynamic>,
    );
    return list.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> toggleFavorite(String listingId) async {
    return _api.post<Map<String, dynamic>>(
      '/users/favorites/$listingId',
      {},
      (d) => d as Map<String, dynamic>,
    );
  }
}
