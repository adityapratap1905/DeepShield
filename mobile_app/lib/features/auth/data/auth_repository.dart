import '../../../core/services/storage_service.dart';
import '../../../models/user_model.dart';

/// Auth repository — pure local/mock implementation.
/// No backend required. Works entirely offline with SharedPreferences.
class AuthRepository {
  // ── Login ────────────────────────────────────────────────────────
  /// Validates credentials against locally stored account.
  /// Accepts any email + password (≥ 6 chars) for demo purposes.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 900));

    final storage = StorageService.instance;

    // Check if a registered account exists for this email
    final storedEmail = storage.getString('reg_email_${email.toLowerCase()}');
    final storedPassword = storage.getString('reg_password_${email.toLowerCase()}');

    if (storedEmail != null && storedPassword != null) {
      // Registered user — verify password
      if (storedPassword != password) {
        throw Exception('Invalid email or password.');
      }
      final storedName = storage.getString('reg_name_${email.toLowerCase()}') ?? 'User';
      final user = _buildUser(id: email, name: storedName, email: email);
      await _saveSession(user);
      return user;
    }

    // Fallback: accept any email + password ≥ 6 chars as a guest login
    if (password.length < 6) {
      throw Exception('Invalid email or password.');
    }

    final name = email.split('@').first;
    final displayName = name[0].toUpperCase() + name.substring(1);
    final user = _buildUser(id: email, name: displayName, email: email);
    await _saveSession(user);
    return user;
  }

  // ── Register ─────────────────────────────────────────────────────
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final storage = StorageService.instance;

    // Check if email already registered
    final existing = storage.getString('reg_email_${email.toLowerCase()}');
    if (existing != null) {
      throw Exception('An account with this email already exists.');
    }

    // Store registration locally
    await storage.setString('reg_email_${email.toLowerCase()}', email);
    await storage.setString('reg_password_${email.toLowerCase()}', password);
    await storage.setString('reg_name_${email.toLowerCase()}', name);

    final user = _buildUser(id: email, name: name, email: email);
    await _saveSession(user);
    return user;
  }

  // ── Forgot Password ──────────────────────────────────────────────
  Future<void> forgotPassword({required String email}) async {
    // Simulate sending email
    await Future.delayed(const Duration(milliseconds: 700));
    // In a real app this would send an email. Here it's a no-op.
  }

  // ── Logout ───────────────────────────────────────────────────────
  Future<void> logout() async {
    await StorageService.instance.setLoggedIn(false);
    await StorageService.instance.saveUserInfo(name: '', email: '', id: '');
  }

  // ── Helpers ───────────────────────────────────────────────────────
  UserModel _buildUser({
    required String id,
    required String name,
    required String email,
  }) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      totalScans: 42,
      safeScans: 38,
      fakeScans: 4,
      authenticityScore: 92,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<void> _saveSession(UserModel user) async {
    final storage = StorageService.instance;
    await storage.saveToken('mock_token_${user.id}');
    await storage.setLoggedIn(true);
    await storage.saveUserInfo(
      name: user.name,
      email: user.email,
      id: user.id,
    );
  }
}
