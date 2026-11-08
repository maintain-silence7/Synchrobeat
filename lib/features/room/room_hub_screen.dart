import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../common/app_buttons.dart';
import '../common/avatar_circle.dart';
import 'local_room_repository.dart';
import 'room_models.dart';

class RoomHubScreen extends StatefulWidget {
  const RoomHubScreen({super.key});

  @override
  State<RoomHubScreen> createState() => _RoomHubScreenState();
}

class _RoomHubScreenState extends State<RoomHubScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final room = await sl<LocalRoomRepository>().createRoom(user);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.secondary, size: 24),
              SizedBox(width: 10),
              Text('Room Created'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this room code with your friends to listen together:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: SelectableText(
                  room.code,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'https://synchrobeat.app/join/${room.code}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                  text: 'https://synchrobeat.app/join/${room.code}',
                ));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite link copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Link'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Enter Room'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/room');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom(String rawCode) async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null || rawCode.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await sl<LocalRoomRepository>().joinRoom(rawCode, user);
      if (mounted) context.go('/room');
    } on RoomFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = sl<LocalRoomRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Listening Rooms')),
      body: StreamBuilder<Room?>(
        stream: repo.roomStream,
        initialData: repo.currentRoom,
        builder: (context, snapshot) {
          final room = snapshot.data;
          if (room != null) {
            return _ActiveRoomSummary(room: room);
          }
          return _buildLobby();
        },
      ),
    );
  }

  Widget _buildLobby() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero emblem with glowing pulse
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
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.groups_rounded,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Listen together, in perfect sync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a room, share the code, and everyone\'s playback locks '
                'to within ~100 ms of each other — automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryGradientButton(
                onPressed: _busy ? null : _createRoom,
                label: 'Create a Room',
                isLoading: _busy,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                ),
                decoration: const InputDecoration(
                  hintText: 'CODE12',
                  counterText: '',
                  labelText: 'Enter 6-character room code',
                  prefixIcon: Icon(Icons.tag_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
                onChanged: (value) {
                  if (value.trim().length == 6) _joinRoom(value);
                },
                onSubmitted: _joinRoom,
              ),
              const SizedBox(height: 14),
              SecondaryOutlinedButton(
                onPressed:
                    _busy ? null : () => _joinRoom(_codeController.text),
                label: 'Join Room',
                accentColor: AppTheme.secondary,
                icon: const Icon(Icons.login_rounded,
                    size: 18, color: AppTheme.secondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Demo mode: rooms persist for this session and are stored on-device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRoomSummary extends StatelessWidget {
  const _ActiveRoomSummary({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    RoomMember? host;
    for (final m in room.members) {
      if (m.isHost) {
        host = m;
        break;
      }
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.surfaceBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.graphic_eq_rounded,
                      size: 48, color: AppTheme.secondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Active Room Session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    room.code,
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final member in room.members)
                      Chip(
                        avatar: AvatarCircle(
                          emoji: member.avatarEmoji,
                          colorValue: member.avatarColorValue,
                          radius: 12,
                          fontSize: 12,
                        ),
                        label: Text(
                          member.id == host?.id
                              ? '${member.displayName} · DJ'
                              : member.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppTheme.surfaceElevated,
                        side: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                PrimaryGradientButton(
                  onPressed: () => context.go('/room'),
                  label: 'Enter Room',
                  icon: const Icon(Icons.headphones_rounded,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _leave(context),
                  child: const Text(
                    'Leave room',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leave(BuildContext context) async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave room?'),
            content: const Text(
              'Playback stops for you. If you are the host, the DJ role is handed to the longest-waiting listener.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await sl<LocalRoomRepository>().leaveRoom(user);
    }
  }
}
