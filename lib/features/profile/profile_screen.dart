import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_bloc.dart';
import '../common/app_buttons.dart';
import '../common/avatar_circle.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    final user = (sl<AuthBloc>().state as AuthAuthenticated).user;
    _nameController = TextEditingController(text: user.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final value = _nameController.text.trim();
    if (value.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name must be at least 3 characters'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    sl<AuthBloc>().add(ProfileUpdateRequested(displayName: value));
    setState(() => _editingName = false);
  }

  void _updateAvatar({String? emoji, int? colorValue}) {
    sl<AuthBloc>().add(
      ProfileUpdateRequested(avatarEmoji: emoji, avatarColorValue: colorValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocBuilder<AuthBloc, AuthState>(
        bloc: sl<AuthBloc>(),
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = state.user;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Avatar Hero with ambient glow
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(user.avatarColorValue)
                            .withValues(alpha: 0.45),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AvatarCircle(
                    emoji: user.avatarEmoji,
                    colorValue: user.avatarColorValue,
                    radius: 54,
                    fontSize: 50,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'OFFLINE DEMO BUILD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionLabel('DISPLAY NAME'),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: TextField(
                          controller: _nameController,
                          enabled: _editingName,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Display name',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (_editingName) ...[
                      IconButton(
                        onPressed: _saveName,
                        icon: const Icon(Icons.check_rounded,
                            color: AppTheme.secondary),
                      ),
                      IconButton(
                        onPressed: () {
                          _nameController.text = user.displayName;
                          setState(() => _editingName = false);
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary),
                      ),
                    ] else
                      IconButton(
                        onPressed: () => setState(() => _editingName = true),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('AVATAR VIBE'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in kAvatarEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _updateAvatar(emoji: emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: user.avatarEmoji == emoji
                              ? AppTheme.primary.withValues(alpha: 0.35)
                              : AppTheme.surface,
                          border: Border.all(
                            color: user.avatarEmoji == emoji
                                ? AppTheme.primaryAccent
                                : AppTheme.surfaceBorder,
                            width: user.avatarEmoji == emoji ? 1.8 : 1,
                          ),
                        ),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const _SectionLabel('ACCENT COLOR'),
              Row(
                children: [
                  for (final color in kAvatarColors)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _updateAvatar(colorValue: color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: user.avatarColorValue == color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: user.avatarColorValue == color
                                ? [
                                    BoxShadow(
                                      color: Color(color).withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              const _SectionLabel('SYNC ENGINE TELEMETRY'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.av_timer_rounded,
                          color: AppTheme.secondary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NTP-style clock sync, 60s resync',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Drift correction engages at 100 ms (rate warp) and 350 ms (hard seek).',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SecondaryOutlinedButton(
                onPressed: () {
                  sl<AuthBloc>().add(const SignOutRequested());
                  context.go('/login');
                },
                label: 'Sign Out',
                accentColor: AppTheme.error,
                icon: const Icon(Icons.logout_rounded,
                    color: AppTheme.error, size: 18),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'SynchroBeat 1.0.0 · Offline demo',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
