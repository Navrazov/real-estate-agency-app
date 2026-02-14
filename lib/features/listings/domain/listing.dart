enum PropertyType { apartment, house, land, commercial }

enum ApartmentType { newBuilding, secondary }

enum ListingStatus { pending, active, sold, rented }

enum ModerationStatus { pending, approved, rejected }

enum PaymentType { cash, installment }

extension PropertyTypeExtension on PropertyType {
  String get label {
    switch (this) {
      case PropertyType.apartment:
        return 'Квартира';
      case PropertyType.house:
        return 'Дом';
      case PropertyType.land:
        return 'Участок';
      case PropertyType.commercial:
        return 'Коммерция';
    }
  }

  String get icon {
    switch (this) {
      case PropertyType.apartment:
        return '🏢';
      case PropertyType.house:
        return '🏠';
      case PropertyType.land:
        return '🌳';
      case PropertyType.commercial:
        return '🏪';
    }
  }

  String get apiValue {
    return toString().split('.').last;
  }
}

extension ApartmentTypeExtension on ApartmentType {
  String get label {
    switch (this) {
      case ApartmentType.newBuilding:
        return 'Новостройка';
      case ApartmentType.secondary:
        return 'Вторичка';
    }
  }

  String get icon {
    switch (this) {
      case ApartmentType.newBuilding:
        return '🏗️';
      case ApartmentType.secondary:
        return '🏢';
    }
  }

  String get apiValue {
    switch (this) {
      case ApartmentType.newBuilding:
        return 'new';
      case ApartmentType.secondary:
        return 'secondary';
    }
  }
}

extension ListingStatusExtension on ListingStatus {
  String get label {
    switch (this) {
      case ListingStatus.pending:
        return 'На модерации';
      case ListingStatus.active:
        return 'Активно';
      case ListingStatus.sold:
        return 'Продано';
      case ListingStatus.rented:
        return 'Сдано';
    }
  }
}

extension ModerationStatusExtension on ModerationStatus {
  String get label {
    switch (this) {
      case ModerationStatus.pending:
        return 'Ожидает проверки';
      case ModerationStatus.approved:
        return 'Одобрено';
      case ModerationStatus.rejected:
        return 'Отклонено';
    }
  }
}

extension PaymentTypeExtension on PaymentType {
  String get label {
    switch (this) {
      case PaymentType.cash:
        return 'Наличные';
      case PaymentType.installment:
        return 'Рассрочка';
    }
  }

  String get icon {
    switch (this) {
      case PaymentType.cash:
        return '💵';
      case PaymentType.installment:
        return '📅';
    }
  }
}

class Listing {
  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.paymentType = PaymentType.cash,
    this.installmentMonths,
    this.installmentMonthly,
    required this.address,
    required this.authorId,
    required this.images,
    this.propertyType = PropertyType.apartment,
    this.apartmentType,
    this.developer,
    this.complex,
    this.rooms,
    this.area,
    this.floor,
    this.totalFloors,
    this.status = ListingStatus.active,
    this.moderationStatus = ModerationStatus.pending,
    this.moderationNote,
    this.views = 0,
    this.authorName,
    this.authorPhone,
    this.isFavorite = false,
    this.lat,
    this.lng,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final PaymentType paymentType;
  final int? installmentMonths;
  final double? installmentMonthly;
  final String address;
  final String authorId;
  final List<String> images;
  final PropertyType propertyType;
  final ApartmentType? apartmentType;
  final String? developer;
  final String? complex;
  final int? rooms;
  final double? area;
  final int? floor;
  final int? totalFloors;
  final ListingStatus status;
  final ModerationStatus moderationStatus;
  final String? moderationNote;
  final int views;
  final String? authorName;
  final String? authorPhone;
  final bool isFavorite;
  final double? lat;
  final double? lng;
  final String createdAt;
  final String updatedAt;

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      paymentType: _parsePaymentType(json['paymentType'] as String?),
      installmentMonths: json['installmentMonths'] as int?,
      installmentMonthly: (json['installmentMonthly'] as num?)?.toDouble(),
      address: json['address'] as String,
      authorId: json['authorId'] as String,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      propertyType: _parsePropertyType(json['propertyType'] as String?),
      apartmentType: _parseApartmentType(json['apartmentType'] as String?),
      developer: json['developer'] as String?,
      complex: json['complex'] as String?,
      rooms: json['rooms'] as int?,
      area: (json['area'] as num?)?.toDouble(),
      floor: json['floor'] as int?,
      totalFloors: json['totalFloors'] as int?,
      status: _parseStatus(json['status'] as String?),
      moderationStatus: _parseModerationStatus(json['moderationStatus'] as String?),
      moderationNote: json['moderationNote'] as String?,
      views: json['views'] as int? ?? 0,
      authorName: json['authorName'] as String?,
      authorPhone: json['authorPhone'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  static PropertyType _parsePropertyType(String? value) {
    switch (value) {
      case 'house':
        return PropertyType.house;
      case 'land':
        return PropertyType.land;
      case 'commercial':
        return PropertyType.commercial;
      default:
        return PropertyType.apartment;
    }
  }

  static ApartmentType? _parseApartmentType(String? value) {
    switch (value) {
      case 'new':
        return ApartmentType.newBuilding;
      case 'secondary':
        return ApartmentType.secondary;
      default:
        return null;
    }
  }

  static PaymentType _parsePaymentType(String? value) {
    switch (value) {
      case 'installment':
        return PaymentType.installment;
      default:
        return PaymentType.cash;
    }
  }

  static ListingStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return ListingStatus.pending;
      case 'sold':
        return ListingStatus.sold;
      case 'rented':
        return ListingStatus.rented;
      default:
        return ListingStatus.active;
    }
  }

  static ModerationStatus _parseModerationStatus(String? value) {
    switch (value) {
      case 'approved':
        return ModerationStatus.approved;
      case 'rejected':
        return ModerationStatus.rejected;
      default:
        return ModerationStatus.pending;
    }
  }

  String get propertyTypeValue {
    return propertyType.toString().split('.').last;
  }

  String get statusValue {
    return status.toString().split('.').last;
  }

  String get paymentTypeValue {
    return paymentType.toString().split('.').last;
  }

  Listing copyWith({
    bool? isFavorite,
  }) {
    return Listing(
      id: id,
      title: title,
      description: description,
      price: price,
      paymentType: paymentType,
      installmentMonths: installmentMonths,
      installmentMonthly: installmentMonthly,
      address: address,
      authorId: authorId,
      images: images,
      propertyType: propertyType,
      apartmentType: apartmentType,
      developer: developer,
      complex: complex,
      rooms: rooms,
      area: area,
      floor: floor,
      totalFloors: totalFloors,
      status: status,
      moderationStatus: moderationStatus,
      moderationNote: moderationNote,
      views: views,
      authorName: authorName,
      authorPhone: authorPhone,
      isFavorite: isFavorite ?? this.isFavorite,
      lat: lat,
      lng: lng,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class FilterOptions {
  final List<String> developers;
  final List<String> complexes;

  FilterOptions({required this.developers, required this.complexes});
}

class ListingsResponse {
  final List<Listing> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  ListingsResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ListingsResponse.fromJson(Map<String, dynamic> json) {
    return ListingsResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => Listing.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
