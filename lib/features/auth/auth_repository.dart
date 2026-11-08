import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/json_store.dart';
import 'app_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Authentication contract. The app ships with [LocalAuthRepository] (offline
/// demo mode); a Supabase-backed implementation can be swapped in via DI
/// without touching the UI layer.
abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signInDemo();
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String avatarEmoji,
    required int avatarColorValue,
  });
  Future<void> signOut();
  Future<AppUser> updateProfile({
    String? displayName,
    String? avatarEmoji,
    int? avatarColorValue,
  });
}

/// Offline demo implementation: accounts are stored in a local JSON file with
/// SHA-256 salted password hashes, and the session token lives in the platform
/// secure storage (Keychain / EncryptedSharedPreferences).
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._secureStorage);

  static const _usersFile = 'auth_users.json';
  static const _sessionKey = 'synchrobeat_session_user_id';
  static const _demoEmail = 'demo@synchrobeat.app';
  static const _demoPassword = 'demo1234';

  final FlutterSecureStorage _secureStorage;
  final _controller = StreamController<AppUser?>.broadcast();
  final _uuid = const Uuid();

  JsonStore? _store;
  List<Map<String, dynamic>>? _users;
  AppUser? _current;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  Future<JsonStore> get _s async => _store ??= await JsonStore.open();

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final cached = _users;
    if (cached != null) return cached;
    final store = await _s;
    final raw = await store.readList(_usersFile);
    var users = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (users.isEmpty) {
      // Seed a demo account so the app is explorable out of the box.
      users = [_seedDemoUser()];
      await store.write(_usersFile, users);
    }
    _users = users;
    return users;
  }

  Map<String, dynamic> _seedDemoUser() {
    const salt = 'synchrobeat-demo-salt';
    return {
      'id': _uuid.v4(),
      'email': _demoEmail,
      'displayName': 'Demo DJ',
      'avatarEmoji': '🎧',
      'avatarColorValue': 0xFF6C5CE7,
      'salt': salt,
      'passHash': _hash(salt, _demoPassword),
    };
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static AppUser _toUser(Map<String, dynamic> record) => AppUser(
        id: record['id'] as String,
        email: record['email'] as String,
        displayName: record['displayName'] as String? ?? 'Listener',
        avatarEmoji: record['avatarEmoji'] as String? ?? '🎧',
        avatarColorValue: (record['avatarColorValue'] as int?) ?? 0xFF6C5CE7,
      );

  Future<void> _persist(List<Map<String, dynamic>> users) async {
    _users = users;
    await (await _s).write(_usersFile, users);
  }

  void _setCurrent(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<AppUser?> restoreSession() async {
    try {
      // Guard against platform channels that never answer (e.g. test VM).
      final id = await _secureStorage
          .read(key: _sessionKey)
          .timeout(const Duration(seconds: 2));
      if (id == null) {
        _setCurrent(null);
        return null;
      }
      final users = await _loadUsers();
      final match = users.where((u) => u['id'] == id);
      if (match.isEmpty) {
        await _secureStorage.delete(key: _sessionKey);
        _setCurrent(null);
        return null;
      }
      final user = _toUser(match.first);
      _setCurrent(user);
      return user;
    } catch (_) {
      // Secure storage / FS unavailable (e.g. unit tests) → treat as signed out.
      _setCurrent(null);
      return null;
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    // Dummy auth: accept any credentials and sign in (or create) a local user.
    final users = await _loadUsers();
    final normalized = email.trim().toLowerCase();
    final effectiveEmail = normalized.isEmpty ? _demoEmail : normalized;
    final match = users.where((u) => u['email'] == effectiveEmail);
    Map<String, dynamic> record;
    if (match.isNotEmpty) {
      record = match.first;
    } else {
      final salt = _uuid.v4();
      record = {
        'id': _uuid.v4(),
        'email': effectiveEmail,
        'displayName': effectiveEmail.split('@').first,
        'avatarEmoji': '🎧',
        'avatarColorValue': 0xFF6C5CE7,
        'salt': salt,
        'passHash': _hash(salt, password.isEmpty ? 'dummy' : password),
      };
      await _persist([...users, record]);
    }
    final user = _toUser(record);
    try {
      await _secureStorage
          .write(key: _sessionKey, value: user.id)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser> signInDemo() async {
    // Dummy auth: go straight in with the seeded demo profile.
    const user = AppUser(
      id: 'demo-user',
      email: _demoEmail,
      displayName: 'Demo DJ',
      avatarEmoji: '🎧',
      avatarColorValue: 0xFF6C5CE7,
    );
    try {
      await _secureStorage
          .write(key: _sessionKey, value: user.id)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String avatarEmoji,
    required int avatarColorValue,
  }) async {
    // Dummy auth: accept any input and create/use a local profile.
    final normalized = email.trim().toLowerCase();
    final effectiveEmail =
        normalized.isEmpty || !normalized.contains('@') ? _demoEmail : normalized;
    final effectiveName = displayName.trim().isEmpty ? 'Listener' : displayName.trim();
    final users = await _loadUsers();
    final existing = users.where((u) => u['email'] == effectiveEmail);
    Map<String, dynamic> record;
    if (existing.isNotEmpty) {
      record = {
        ...existing.first,
        'displayName': effectiveName,
        'avatarEmoji': avatarEmoji,
        'avatarColorValue': avatarColorValue,
      };
      await _persist([
        for (final u in users) if (u['id'] == record['id']) record else u,
      ]);
    } else {
      final salt = _uuid.v4();
      record = {
        'id': _uuid.v4(),
        'email': effectiveEmail,
        'displayName': effectiveName,
        'avatarEmoji': avatarEmoji,
        'avatarColorValue': avatarColorValue,
        'salt': salt,
        'passHash': _hash(salt, password.isEmpty ? 'dummy' : password),
      };
      await _persist([...users, record]);
    }
    final user = _toUser(record);
    try {
      await _secureStorage
          .write(key: _sessionKey, value: user.id)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    _setCurrent(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (_) {}
    _setCurrent(null);
  }

  @override
  Future<AppUser> updateProfile({
    String? displayName,
    String? avatarEmoji,
    int? avatarColorValue,
  }) async {
    final current = _current;
    if (current == null) throw const AuthFailure('Not signed in.');
    if (displayName != null && displayName.trim().length < 3) {
      throw const AuthFailure('Display name must be at least 3 characters.');
    }
    final updated = current.copyWith(
      displayName: displayName?.trim(),
      avatarEmoji: avatarEmoji,
      avatarColorValue: avatarColorValue,
    );
    final users = await _loadUsers();
    final next = users.map((u) {
      if (u['id'] != updated.id) return u;
      return {
        ...u,
        'displayName': updated.displayName,
        'avatarEmoji': updated.avatarEmoji,
        'avatarColorValue': updated.avatarColorValue,
      };
    }).toList();
    await _persist(next);
    _setCurrent(updated);
    return updated;
  }
}
