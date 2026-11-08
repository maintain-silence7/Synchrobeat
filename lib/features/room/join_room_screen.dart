import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../common/app_buttons.dart';
import 'local_room_repository.dart';

/// Handles deep links of the form `https://synchrobeat.app/join/:code`.
/// Joins the room and forwards into it; shows a recoverable error otherwise.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, required this.code});
  final String code;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    try {
      await sl<LocalRoomRepository>().joinRoom(widget.code, user);
      if (mounted) context.go('/room');
    } on RoomFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not join: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _error == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryAccent,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Connecting to room ${widget.code.toUpperCase()}…',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Synchronizing clocks and room state…',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.link_off_rounded,
                            size: 48, color: AppTheme.error),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to Join Room',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryGradientButton(
                        onPressed: () => context.go('/home'),
                        label: 'Back to Home',
                        isFullWidth: false,
                        icon: const Icon(Icons.home_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
