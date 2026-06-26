import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/fcm_service.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';
import '../data/models/driver_model.dart';
import '../data/models/medical_profile_model.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final MedicalProfileModel? medicalProfile;
  final DriverModel? driver;
  final String? error;
  final String? role;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.medicalProfile,
    this.driver,
    this.error,
    this.role,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    MedicalProfileModel? medicalProfile,
    DriverModel? driver,
    String? error,
    String? role,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      medicalProfile: medicalProfile ?? this.medicalProfile,
      driver: driver ?? this.driver,
      error: clearError ? null : (error ?? this.error),
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    checkAuthStatus();
  }

  // a) Restore session on app start.
  Future<void> checkAuthStatus() async {
    final loggedIn = await _repo.isLoggedIn();
    if (!loggedIn) {
      state = state.copyWith(isAuthenticated: false);
      return;
    }
    try {
      final user = await _repo.getMyProfile();
      final role = await _repo.getStoredRole() ?? user.role;
      state = state.copyWith(isAuthenticated: true, user: user, role: role);
    } catch (_) {
      // Token is invalid/expired — clear and treat as logged out.
      await _repo.logout();
      state = const AuthState();
    }
  }

  // b) Register patient
  Future<bool> registerPatient({
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repo.registerPatient(
        fullName: fullName,
        phone: phone,
        password: password,
        email: email,
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        role: user.role,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return false;
    }
  }

  // c) Register driver
  Future<bool> registerDriver({
    required String fullName,
    required String phone,
    required String password,
    required String vehicleNumber,
    required String licenseNumber,
    String organization = 'Private',
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repo.registerDriver(
        fullName: fullName,
        phone: phone,
        password: password,
        vehicleNumber: vehicleNumber,
        licenseNumber: licenseNumber,
        organization: organization,
        email: email,
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final driver = data['driver'] != null
          ? DriverModel.fromJson(data['driver'] as Map<String, dynamic>)
          : null;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        driver: driver,
        role: user.role,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return false;
    }
  }

  // d) Login patient
  Future<bool> loginPatient({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repo.loginPatient(phone: phone, password: password);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final mp = data['medical_profile'] != null
          ? MedicalProfileModel.fromJson(data['medical_profile'] as Map<String, dynamic>)
          : null;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        medicalProfile: mp,
        role: 'patient',
      );
      FCMService.initialize(); // register for push (best-effort)
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return false;
    }
  }

  // e) Login driver
  Future<bool> loginDriver({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repo.loginDriver(phone: phone, password: password);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final driver = data['driver'] != null
          ? DriverModel.fromJson(data['driver'] as Map<String, dynamic>)
          : null;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        driver: driver,
        role: 'driver',
      );
      FCMService.initialize(); // register for push (best-effort)
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return false;
    }
  }

  // f) Update medical profile
  Future<bool> updateMedicalProfile(MedicalProfileModel profile) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.updateMedicalProfile(profile);
      state = state.copyWith(isLoading: false, medicalProfile: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return false;
    }
  }

  // g) Logout
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}

// --- providers -------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isAuthenticated);

final currentUserProvider =
    Provider<UserModel?>((ref) => ref.watch(authProvider).user);

final currentRoleProvider =
    Provider<String?>((ref) => ref.watch(authProvider).role);
