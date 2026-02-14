import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/features/listings/domain/listing.dart';

void main() {
  group('Listing model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123',
        'title': 'Test Apartment',
        'description': 'Nice place',
        'price': 5000000,
        'paymentType': 'cash',
        'address': 'Moscow, Main St',
        'propertyType': 'apartment',
        'authorId': 'user1',
        'images': ['img1.jpg'],
        'status': 'active',
        'views': 10,
        'isFavorite': false,
        'createdAt': '2024-01-01T00:00:00Z',
        'updatedAt': '2024-01-01T00:00:00Z',
      };

      final listing = Listing.fromJson(json);
      expect(listing.id, '123');
      expect(listing.title, 'Test Apartment');
      expect(listing.price, 5000000.0);
      expect(listing.propertyType, PropertyType.apartment);
      expect(listing.paymentType, PaymentType.cash);
      expect(listing.status, ListingStatus.active);
      expect(listing.views, 10);
      expect(listing.address, 'Moscow, Main St');
      expect(listing.authorId, 'user1');
      expect(listing.images, ['img1.jpg']);
      expect(listing.isFavorite, false);
    });

    test('fromJson handles optional fields', () {
      final json = {
        'id': '456',
        'title': 'House',
        'description': 'Big house',
        'price': 10000000,
        'address': 'SPB',
        'authorId': 'user2',
        'createdAt': '2024-06-01T00:00:00Z',
        'updatedAt': '2024-06-01T00:00:00Z',
      };

      final listing = Listing.fromJson(json);
      expect(listing.id, '456');
      expect(listing.images, isEmpty);
      expect(listing.rooms, isNull);
      expect(listing.area, isNull);
      expect(listing.floor, isNull);
      expect(listing.totalFloors, isNull);
      expect(listing.views, 0);
      expect(listing.isFavorite, false);
      expect(listing.propertyType, PropertyType.apartment); // default
      expect(listing.paymentType, PaymentType.cash); // default
      expect(listing.status, ListingStatus.active); // default
    });

    test('ListingsResponse fromJson parses correctly', () {
      final json = {
        'items': [],
        'total': 0,
        'page': 1,
        'limit': 20,
        'totalPages': 0,
      };

      final response = ListingsResponse.fromJson(json);
      expect(response.items, isEmpty);
      expect(response.total, 0);
      expect(response.page, 1);
      expect(response.limit, 20);
      expect(response.totalPages, 0);
    });

    test('ListingsResponse fromJson parses items', () {
      final json = {
        'items': [
          {
            'id': '1',
            'title': 'Apt 1',
            'description': 'Desc',
            'price': 100,
            'address': 'Addr',
            'authorId': 'a1',
            'createdAt': '2024-01-01T00:00:00Z',
            'updatedAt': '2024-01-01T00:00:00Z',
          },
        ],
        'total': 1,
        'page': 1,
        'limit': 20,
        'totalPages': 1,
      };

      final response = ListingsResponse.fromJson(json);
      expect(response.items.length, 1);
      expect(response.items.first.id, '1');
      expect(response.total, 1);
    });

    test('copyWith updates isFavorite', () {
      final listing = Listing(
        id: '1',
        title: 'Test',
        description: 'Desc',
        price: 100,
        address: 'Addr',
        authorId: 'a1',
        images: [],
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      expect(listing.isFavorite, false);
      final updated = listing.copyWith(isFavorite: true);
      expect(updated.isFavorite, true);
      expect(updated.id, '1');
    });

    test('propertyTypeValue returns string', () {
      final listing = Listing(
        id: '1',
        title: 'Test',
        description: 'Desc',
        price: 100,
        address: 'Addr',
        authorId: 'a1',
        images: [],
        propertyType: PropertyType.house,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      expect(listing.propertyTypeValue, 'house');
      expect(listing.statusValue, 'active');
      expect(listing.paymentTypeValue, 'cash');
    });
  });

  group('PropertyType extension', () {
    test('label returns Russian text', () {
      expect(PropertyType.apartment.label, 'Квартира');
      expect(PropertyType.house.label, 'Дом');
      expect(PropertyType.land.label, 'Участок');
      expect(PropertyType.commercial.label, 'Коммерция');
    });

    test('icon returns emoji', () {
      expect(PropertyType.apartment.icon, '🏢');
      expect(PropertyType.house.icon, '🏠');
      expect(PropertyType.land.icon, '🌳');
      expect(PropertyType.commercial.icon, '🏪');
    });
  });

  group('ListingStatus extension', () {
    test('label returns Russian text', () {
      expect(ListingStatus.active.label, 'Активно');
      expect(ListingStatus.sold.label, 'Продано');
      expect(ListingStatus.rented.label, 'Сдано');
    });
  });

  group('PaymentType extension', () {
    test('label returns Russian text', () {
      expect(PaymentType.cash.label, 'Наличные');
      expect(PaymentType.installment.label, 'Рассрочка');
    });

    test('icon returns emoji', () {
      expect(PaymentType.cash.icon, '💵');
      expect(PaymentType.installment.icon, '📅');
    });
  });
}
