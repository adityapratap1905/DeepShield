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
          : AppThemeMode.light;
  return ThemeNotifier(initial);
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier(super.initial);

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await StorageService.instance.saveThemeMode(mode.name);
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((_) => ProfileRepository());

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

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref.read(profileRepositoryProvider)),
);

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;

  ProfileNotifier(this._repo) : super(ProfileInitial());

  Future<void> loadProfile() async {
    state = ProfileLoading();
    try {
      state = ProfileLoaded(await _repo.getProfile());
    } catch (error) {
      state = ProfileError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> updateProfile(String name, {String bio = ''}) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    try {
      state = ProfileLoaded(await _repo.updateProfile(name: name, bio: bio));
    } catch (_) {
      state = current;
    }
  }
}
