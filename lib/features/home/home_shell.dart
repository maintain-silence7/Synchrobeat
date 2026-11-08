import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../player/mini_player.dart';
import '../profile/profile_screen.dart';
import '../room/room_hub_screen.dart';
import '../vault/vault_screen.dart';

/// Signed-in shell: Vault / Room / Profile tabs with a docked mini player.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  static const _tabs = [
    _HomeTab(
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music_rounded,
      label: 'Vault',
    ),
    _HomeTab(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Room',
    ),
    _HomeTab(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          VaultScreen(),
          RoomHubScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              height: 66,
              selectedIndex: _index,
              backgroundColor: AppTheme.surface,
              surfaceTintColor: Colors.transparent,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab {
  const _HomeTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
