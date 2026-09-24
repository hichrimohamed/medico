import '../../../core/api/api_client.dart';
import 'profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> load();

  /// Renames the patient. Email is deliberately not changeable here — see the
  /// note on `PATCH /me` in the server.
  Future<Profile> rename(String name);

  /// Changes the password, which also ends every other session. The caller has
  /// to expect the current session to survive and the others not to.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Deletes the account and everything hanging off it. Irreversible, and the
  /// password is required again because the session alone is not proof enough
  /// for something that cannot be undone.
  Future<void> deleteAccount(String password);
}

class HttpProfileRepository implements ProfileRepository {
  const HttpProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<Profile> load() async {
    final body = await _api.get('/me');
    return Profile.fromJson((body as Map<String, dynamic>?) ?? const {});
  }

  @override
  Future<Profile> rename(String name) async {
    final body = await _api.patch('/me', body: {'name': name.trim()});
    return Profile.fromJson((body as Map<String, dynamic>?) ?? const {});
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _api.delete('/me', body: {'password': password});
  }
}
