/// AuthGate — decides the initial route after sign-in or on app cold start.
///
/// Redirects to /home if a session exists, otherwise to /onboarding.
/// Also handles the deep-link callback from email OTP (/auth-callback).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auth_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // After sign-in or deep-link callback, redirect based on session state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    });

    // Momentary splash while routing
    return Scaffold(
      backgroundColor: AppColors.onBtn,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.jade, strokeWidth: 2),
      ),
    );
  }
}
