import '../../../core/api/api_client.dart';
import '../domain/notification_model.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient();

  Future<NotificationsResponse> getAll({int page = 1}) {
    return _api.get<NotificationsResponse>(
      '/notifications?page=$page',
      (data) => NotificationsResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<int> getUnreadCount() {
    return _api.get<int>(
      '/notifications/unread-count',
      (data) => (data as Map<String, dynamic>)['count'] as int,
    );
  }

  Future<void> markRead(String id) {
    return _api.patch<void>(
      '/notifications/$id/read',
      {},
      (_) {},
    );
  }

  Future<void> markAllRead() {
    return _api.patch<void>(
      '/notifications/read-all',
      {},
      (_) {},
    );
  }
}
