import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 64, color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'SynchroBeat',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Synchronized Group Audio Streaming',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ),
    // Join deep link handler: https://synchrobeat.app/join/:code
    GoRoute(
      path: '/join/:code',
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return Scaffold(
          appBar: AppBar(title: const Text('Joining Room...')),
          body: Center(
            child: Text('Connecting to room $code...'),
          ),
        );
      },
    ),
  ],
);

class SynchroBeatApp extends StatelessWidget {
  const SynchroBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SynchroBeat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
