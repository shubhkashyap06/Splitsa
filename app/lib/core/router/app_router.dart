/// App router — go_router configuration for all named routes.
///
/// Route hierarchy follows docs/UI_UX_SPEC.md §2 navigation structure exactly.
/// Shell routes wrap the floating PillTabBar; pushed screens (Profile,
/// Room Detail) hide the tab bar by escaping the shell.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_gate.dart';
import '../../features/onboarding/presentation/onboarding_carousel_screen.dart';
import '../../features/onboarding/presentation/email_otp_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../features/pots/presentation/pots_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/pill_tab_bar.dart';
import '../../shared/widgets/home_shell.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    debugLogDiagnostics: true,
    routes: [
      // ── Auth / Onboarding ──────────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (ctx, state) => const OnboardingCarouselScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'auth-otp',
        builder: (ctx, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return EmailOtpScreen(email: email);
        },
      ),

      // ── Auth gate (redirects after sign-in) ───────────────────────────
      GoRoute(
        path: '/auth-gate',
        name: 'auth-gate',
        builder: (ctx, state) => const AuthGate(),
      ),

      // ── Main shell — floating tab bar ─────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => HomeShell(shell: shell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (ctx, state) => const HomeScreen(),
            ),
          ]),
          // Tab 1: Rooms
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/rooms',
              name: 'rooms',
              builder: (ctx, state) => const RoomsScreen(),
              routes: [
                GoRoute(
                  path: ':roomId',
                  name: 'room-detail',
                  builder: (ctx, state) => RoomDetailScreen(
                    roomId: state.pathParameters['roomId']!,
                  ),
                ),
              ],
            ),
          ]),
          // Tab 2: Add (no content — opens expense type sheet from PillTabBar)
          StatefulShellBranch(routes: [
            GoRoute(path: '/add', name: 'add', builder: (ctx, state) => const SizedBox()),
          ]),
          // Tab 3: Pots
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pots',
              name: 'pots',
              builder: (ctx, state) => const PotsScreen(),
            ),
          ]),
          // Tab 4: Insights
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/insights',
              name: 'insights',
              builder: (ctx, state) => const InsightsScreen(),
            ),
          ]),
        ],
      ),

      // ── Pushed screens (hide tab bar) ─────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (ctx, state) => const ProfileScreen(),
      ),

      // ── Deep-link auth callback ────────────────────────────────────────
      GoRoute(
        path: '/auth-callback',
        name: 'auth-callback',
        builder: (ctx, state) => const AuthGate(),
      ),
    ],
  );
}

