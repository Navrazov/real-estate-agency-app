class UserProfile {
  final String id;
  final String? name;
  final String? phone;
  final String? avatar;
  final String createdAt;
  final String? lastSeen;
  final bool online;
  final List<ProfileListing> listings;

  UserProfile({
    required this.id,
    this.name,
    this.phone,
    this.avatar,
    required this.createdAt,
    this.lastSeen,
    this.online = false,
    this.listings = const [],
  });

  String get displayName => name ?? phone ?? 'Пользователь';

  UserProfile copyWith({
    String? lastSeen,
    bool? online,
  }) {
    return UserProfile(
      id: id,
      name: name,
      phone: phone,
      avatar: avatar,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      online: online ?? this.online,
      listings: listings,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      createdAt: json['createdAt'] as String,
      lastSeen: json['lastSeen'] as String?,
      online: json['online'] as bool? ?? false,
      listings: (json['listings'] as List<dynamic>?)
              ?.map((e) => ProfileListing.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ProfileListing {
  final String id;
  final String title;
  final double price;
  final String address;
  final String? propertyType;
  final List<String> images;
  final int? rooms;
  final double? area;
  final String createdAt;

  ProfileListing({
    required this.id,
    required this.title,
    required this.price,
    required this.address,
    this.propertyType,
    this.images = const [],
    this.rooms,
    this.area,
    required this.createdAt,
  });

  factory ProfileListing.fromJson(Map<String, dynamic> json) {
    return ProfileListing(
      id: json['id'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      address: json['address'] as String,
      propertyType: json['propertyType'] as String?,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      rooms: json['rooms'] as int?,
      area: (json['area'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String,
    );
  }
}
