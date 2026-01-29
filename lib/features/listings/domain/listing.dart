class Listing {
  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.address,
    required this.authorId,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String address;
  final String authorId;
  final List<String> images;
  final String createdAt;
  final String updatedAt;

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      address: json['address'] as String,
      authorId: json['authorId'] as String,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
