import '../../../core/api/api_client.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  final ApiClient _api = ApiClient();

  Future<UserProfile> getProfile(String userId) async {
    return _api.get<UserProfile>(
      '/users/profile/$userId',
      (data) => UserProfile.fromJson(data as Map<String, dynamic>),
      withAuth: false,
    );
  }
}
