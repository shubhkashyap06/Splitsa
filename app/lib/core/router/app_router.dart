/// App router — go_router configuration for all routes.
///
/// Route hierarchy follows docs/UI_UX_SPEC.md §2. Shell routes wrap the
/// floating PillTabBar; pushed screens (Profile, Delete Account) escape the
/// shell so the tab bar hides itself.
///
/// Deep links (SECURITY.md §2 "Platform"): `/quick-add?type=…` and
/// `/join?code=…` are validated against an allow-list / strict pattern here,
/// before anything dispatches on them — never reflected into a route.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/remote/supabase_service.dart';
import '../config/app_config.dart';
import '../../features/auth/presentation/auth_gate.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/onboarding/presentation/email_otp_screen.dart';
import '../../features/onboarding/presentation/onboarding_carousel_screen.dart';
import '../../features/pots/presentation/pots_screen.dart';
import '../../features/profile/presentation/delete_account_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../shared/widgets/home_shell.dart';

part 'app_router.g.dart';

/// Quick-add types the fast-launch shortcuts may request (PRODUCT_LOGIC.md §4).
const kQuickAddTypes = {'split', 'personal', 'pot-contribution'};

final _inviteCodePattern = RegExp(r'^([A-HJ-NP-Z2-9]{6}|[0-9a-f]{64})$');

/// A deep link that arrived before sign-in, replayed after it.
String? _pendingDeepLink;

const _publicPaths = {'/onboarding', '/auth/otp'};

/// Root navigator — routes pinned here render above the shell, which hides
/// the floating tab bar (Room Detail, like Profile, is a pushed screen).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  final authChanges = _StreamListenable(
    SupabaseService.client.auth.onAuthStateChange,
  );
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authChanges,
    redirect: (context, state) {
      // Read auth directly: the refresh listener and currentUserIdProvider's
      // invalidation fire off the same stream in no guaranteed order.
      final signedIn =
          AppConfig.instance.demoMode ||
          SupabaseService.client.auth.currentUser != null;
      final path = state.uri.path;

      // ── Validate deep links first ──────────────────────────────────────
      if (path == '/quick-add') {
        final type = state.uri.queryParameters['type'];
        final target = kQuickAddTypes.contains(type)
            ? '/home?quick=$type'
            : '/home';
        if (!signedIn) {
          _pendingDeepLink = target;
          return '/onboarding';
        }
        return target;
      }
      if (path == '/join') {
        final code = state.uri.queryParameters['code']?.trim() ?? '';
        final target = _inviteCodePattern.hasMatch(code)
            ? '/rooms?join=${Uri.encodeQueryComponent(code)}'
            : '/rooms';
        if (!signedIn) {
          _pendingDeepLink = target;
          return '/onboarding';
        }
        return target;
      }

      // ── Session gate ──────────────────────────────────────────────────
      final isPublic = _publicPaths.contains(path);
      if (!signedIn && !isPublic) return '/onboarding';
      // Demo builds may open onboarding directly so it can be previewed.
      final demoPreview = AppConfig.instance.demoMode && path == '/onboarding';
      if (signedIn &&
          !demoPreview &&
          (isPublic || path == '/auth-gate' || path == '/auth-callback')) {
        final next = _pendingDeepLink;
        _pendingDeepLink = null;
        return next ?? '/home';
      }
      return null;
    },
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
        builder: (ctx, state) =>
            EmailOtpScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/auth-gate',
        name: 'auth-gate',
        builder: (ctx, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/auth-callback',
        name: 'auth-callback',
        builder: (ctx, state) => const AuthGate(),
      ),
      // Deep-link entry points — always redirected above, never rendered.
      GoRoute(path: '/quick-add', builder: (ctx, state) => const AuthGate()),
      GoRoute(path: '/join', builder: (ctx, state) => const AuthGate()),

      // ── Main shell — floating tab bar ─────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (ctx, state) => HomeScreen(
                  quickAddType: state.uri.queryParameters['quick'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rooms',
                name: 'rooms',
                builder: (ctx, state) =>
                    RoomsScreen(joinCode: state.uri.queryParameters['join']),
                routes: [
                  GoRoute(
                    path: ':roomId',
                    name: 'room-detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (ctx, state) => RoomDetailScreen(
                      roomId: state.pathParameters['roomId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2 is the raised Add button — it opens a sheet, never navigates.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                name: 'add',
                redirect: (ctx, state) => '/home',
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pots',
                name: 'pots',
                builder: (ctx, state) => const PotsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                name: 'insights',
                builder: (ctx, state) => const InsightsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Pushed screens (hide tab bar) ─────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (ctx, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'delete',
            name: 'delete-account',
            builder: (ctx, state) => const DeleteAccountScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Adapts a Stream to the Listenable go_router wants for refreshes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
