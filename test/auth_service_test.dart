import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';

void main() {
  group('User model', () {
    test('constructor creates user with all fields', () {
      final user = User(
        id: '123',
        role: 'user',
        name: 'Test User',
        phone: '+7999123456',
        avatar: 'avatar.jpg',
        favorites: ['listing1', 'listing2'],
      );

      expect(user.id, '123');
      expect(user.role, 'user');
      expect(user.name, 'Test User');
      expect(user.phone, '+7999123456');
      expect(user.avatar, 'avatar.jpg');
      expect(user.favorites, ['listing1', 'listing2']);
    });

    test('constructor uses default values for optional fields', () {
      final user = User(id: '1', role: 'user');

      expect(user.name, isNull);
      expect(user.phone, isNull);
      expect(user.avatar, isNull);
      expect(user.favorites, isEmpty);
    });

    test('displayName returns name when available', () {
      final user = User(id: '1', role: 'user', name: 'John');
      expect(user.displayName, 'John');
    });

    test('displayName returns email prefix when name is null', () {
      final user = User(id: '1', role: 'user');
      expect(user.displayName, 'john');
    });

    test('displayName returns email prefix for complex emails', () {
      final user = User(id: '1', role: 'user');
      expect(user.displayName, 'john.doe');
    });

    test('isAdmin returns true for admin role', () {
      final user = User(id: '1', role: 'admin');
      expect(user.isAdmin, true);
    });

    test('isAdmin returns false for user role', () {
      final user = User(id: '1', role: 'user');
      expect(user.isAdmin, false);
    });

    test('isAdmin returns false for other roles', () {
      final user = User(id: '1', role: 'moderator');
      expect(user.isAdmin, false);
    });
  });
}
