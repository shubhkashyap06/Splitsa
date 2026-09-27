import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../../../data/remote/supabase_service.dart';
import '../../../data/local/database.dart';

part 'auth_provider.g.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

@riverpod
Stream<AuthState> authState(Ref ref) =>
    SupabaseService.client.auth.onAuthStateChange;

@riverpod
User? currentUser(Ref ref) =>
    SupabaseService.client.auth.currentUser;

// ── Email OTP ─────────────────────────────────────────────────────────────────

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Sends a 6-digit OTP to [email].
  /// On Supabase, signInWithOtp(email:) defaults to email OTP (not magic link)
  /// when the user has previously signed in, or creates a new account otherwise.
  Future<void> sendEmailOtp(String email) async {
    state = const AsyncLoading();
    try {
      await SupabaseService.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Verifies the 6-digit OTP and signs in.
  /// On success, the handle_new_user DB trigger creates a profile row.
  /// We cache it locally via [_cacheProfile].
  Future<bool> verifyEmailOtp(String email, String otp) async {
    state = const AsyncLoading();
    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      if (res.user != null) {
        await _cacheProfile(res.user!);
        state = const AsyncData(null);
        return true;
      }
      state = AsyncError(Exception('Verification failed'), StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await SupabaseService.client.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _cacheProfile(User user) async {
    final db = ref.read(appDatabaseProvider);
    await db.profileDao.upsertProfile(
      ProfilesTableCompanion.insert(
        id:          user.id,
        displayName: user.userMetadata?['display_name'] as String? ??
            user.email?.split('@').first ??
            'User',
        email:       Value(user.email),
        createdAt:   DateTime.now(),
        updatedAt:   DateTime.now(),
      ),
    );
  }
}
