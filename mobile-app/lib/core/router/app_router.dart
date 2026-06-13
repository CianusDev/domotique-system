import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_notifier.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/devices/domain/devices_notifier.dart';
import '../../features/devices/presentation/devices_screen.dart';
import '../../features/sensors/presentation/sensors_screen.dart';

// ── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);

      // Only redirect to splash before first auth check.
      // During loading (login/register/verify ops), stay on current page
      // so the screen can show its own loading UI.
      if (authState.isInitial) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (authState.isLoading) return null;

      final isAuth = authState.isAuthenticated;
      final loc = state.matchedLocation;

      const authPages = [
        '/login',
        '/register',
        '/verify-email',
        '/forgot-password',
        '/reset-password',
        '/splash',
      ];
      final isAuthPage = authPages.any((p) => loc.startsWith(p));

      if (!isAuth && !isAuthPage) return '/login';
      if (isAuth && isAuthPage) return '/devices';
      return null;
    },
    routes: [
      // ── Splash / auth init ───────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, _) => const _SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => ForgotPasswordScreen(
          initialEmail: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          initialEmail: state.extra as String? ?? '',
        ),
      ),

      // ── App shell ─────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/devices',
            builder: (_, _) => const DevicesScreen(),
            routes: [
              GoRoute(
                path: ':id/sensors',
                builder: (_, state) => _SensorsScreenWrapper(
                  deviceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/automations',
            builder: (_, _) => const _PlaceholderScreen(
              title: 'Automatisations',
              icon: Icons.rule,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const _ProfileScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ── Refresh notifier bridging Riverpod → GoRouter ────────────────────────────

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) {
      notifyListeners();
    });
  }
}

// ── App shell with bottom nav ────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _tabs = [
    (label: 'Appareils', icon: Icons.developer_board, path: '/devices'),
    (label: 'Automations', icon: Icons.rule, path: '/automations'),
    (label: 'Profil', icon: Icons.person_outline, path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Sensors wrapper (resolves device name from cached state) ─────────────────

class _SensorsScreenWrapper extends ConsumerWidget {
  final String deviceId;
  const _SensorsScreenWrapper({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesNotifierProvider);
    final deviceName = devicesAsync.whenOrNull(
          data: (list) => list
              .where((d) => d.id == deviceId)
              .map((d) => d.name)
              .firstOrNull,
        ) ??
        'Capteurs';

    return SensorsScreen(deviceId: deviceId, deviceName: deviceName);
  }
}

// ── Splash ───────────────────────────────────────────────────────────────────

class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();

  @override
  ConsumerState<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authNotifierProvider.notifier).checkAuth();
      // Navigate imperatively — avoids GoRouter refreshListenable race condition
      // where notifyListeners() fires before GoRouter attaches its listener.
      if (mounted) {
        final authState = ref.read(authNotifierProvider);
        if (authState.isAuthenticated) {
          context.go('/devices');
        } else {
          context.go('/login');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ── Profile screen ───────────────────────────────────────────────────────────

class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              CircleAvatar(
                radius: 36,
                child: Text(
                  user.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
                child: const Text('Se déconnecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 72,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'À venir',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
