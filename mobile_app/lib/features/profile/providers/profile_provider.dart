import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/user_model.dart';
import '../data/profile_repository.dart';

/// Theme mode state
enum AppThemeMode { dark, light, system }

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  final saved = StorageService.instance.themeMode;
  final initial = saved == 'light'
      ? AppThemeMode.light
      : saved == 'system'
          ? AppThemeMode.system
          : AppThemeMode.dark;
  return ThemeNotifier(initial);
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier(super.initial);

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await StorageService.instance.saveThemeMode(mode.name);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((_) => ProfileRepository());

/// User profile state
abstract class ProfileState {}
class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final UserModel user;
  ProfileLoaded(this.user);
}
class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;

  ProfileNotifier(this._repo) : super(ProfileInitial());

  Future<void> loadProfile() async {
    state = ProfileLoading();

    // Mock data — replace with: final user = await _repo.getProfile();
    await Future.delayed(const Duration(milliseconds: 600));
    final storage = StorageService.instance;

    state = ProfileLoaded(UserModel(
      id: storage.userId.isEmpty ? 'mock-1' : storage.userId,
      name: storage.userName.isEmpty ? 'Alex Johnson' : storage.userName,
      email: storage.userEmail.isEmpty ? 'alex@deepshield.io' : storage.userEmail,
      totalScans: 142,
      safeScans: 124,
      fakeScans: 18,
      authenticityScore: 87,
      createdAt: DateTime(2024, 1, 15),
    ));
  }

  Future<void> updateProfile(String name) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    try {
      final updated = await _repo.updateProfile(name: name);
      state = ProfileLoaded(updated);
    } catch (_) {
      state = current;
    }
  }
}
