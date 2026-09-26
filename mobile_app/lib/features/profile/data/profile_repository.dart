import '../../../core/services/storage_service.dart';
import '../../../models/user_model.dart';

/// Profile repository — pure local/mock implementation.
/// No backend required. Reads/writes to SharedPreferences.
class ProfileRepository {
  Future<UserModel> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final storage = StorageService.instance;
    return UserModel(
      id: storage.userId.isEmpty ? 'local_user' : storage.userId,
      name: storage.userName.isEmpty ? 'User' : storage.userName,
      email: storage.userEmail.isEmpty ? 'user@example.com' : storage.userEmail,
      totalScans: 42,
      safeScans: 38,
      fakeScans: 4,
      authenticityScore: 92,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<UserModel> updateProfile({required String name}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final storage = StorageService.instance;
    await storage.saveUserInfo(
      name: name,
      email: storage.userEmail,
      id: storage.userId,
    );
    return getProfile();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // In a real app this would validate the current password.
    // For demo purposes, any non-empty newPassword is accepted.
    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters.');
    }
    // Update stored password if registration data exists
    final storage = StorageService.instance;
    final email = storage.userEmail.toLowerCase();
    if (email.isNotEmpty) {
      await storage.setString('reg_password_$email', newPassword);
    }
  }

  Future<String?> uploadAvatar(dynamic imageFile) async {
    // Avatar upload is a no-op in the mock implementation.
    await Future.delayed(const Duration(milliseconds: 800));
    return null;
  }
}
