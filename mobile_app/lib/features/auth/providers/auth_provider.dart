import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/user_model.dart';
import '../data/auth_repository.dart';

// ── Auth State ─────────────────────────────────────────────────────

/// Possible auth states
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// ── Providers ──────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

/// Auth state notifier — manages login, registration, and logout
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(AuthInitial());

  Future<void> login({required String email, required String password}) async {
    state = AuthLoading();
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthAuthenticated(user);
    } on Exception catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    } catch (_) {
      state = AuthError('An unexpected error occurred.');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(name: name, email: email, password: password);
      state = AuthAuthenticated(user);
    } on Exception catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    } catch (_) {
      state = AuthError('An unexpected error occurred.');
    }
  }

  Future<void> forgotPassword(String email) async {
    state = AuthLoading();
    try {
      await _repo.forgotPassword(email: email);
      state = AuthUnauthenticated(); // Reset so UI can show success
    } on Exception catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthUnauthenticated();
  }

  void clearError() {
    if (state is AuthError) state = AuthUnauthenticated();
  }
}

/// Simple boolean provider — true if the user is currently logged in
final isLoggedInProvider = Provider<bool>((ref) {
  return StorageService.instance.isLoggedIn;
});
