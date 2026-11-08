import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_bloc.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_shell.dart';
import 'features/player/full_player_screen.dart';
import 'features/room/join_room_screen.dart';
import 'features/room/room_screen.dart';

/// Notifies go_router to re-evaluate redirects whenever auth state changes.
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter buildRouter() {
  final authBloc = sl<AuthBloc>();
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';

      if (auth is AuthLoading) {
        return location == '/' ? null : '/';
      }
      final isAuthed = auth is AuthAuthenticated;
      if (!isAuthed) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute || location == '/') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/room',
        builder: (context, state) => const RoomScreen(),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullPlayerScreen(),
      ),
      // Deep link: https://synchrobeat.app/join/:code
      GoRoute(
        path: '/join/:code',
        builder: (context, state) => JoinRoomScreen(
          code: state.pathParameters['code'] ?? '',
        ),
      ),
    ],
  );
}

class SynchroBeatApp extends StatefulWidget {
  const SynchroBeatApp({super.key});

  @override
  State<SynchroBeatApp> createState() => _SynchroBeatAppState();
}

class _SynchroBeatAppState extends State<SynchroBeatApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SynchroBeat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF231B42), AppTheme.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF8C7CFF), AppTheme.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.45),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SynchroBeat',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Synchronized Group Audio Streaming',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
