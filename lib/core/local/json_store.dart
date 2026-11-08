import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Minimal JSON-file persistence layer backed by the app support directory.
/// Used in offline/demo mode; the Supabase repositories are the production path.
class JsonStore {
  JsonStore._(this.root);

  final Directory root;
  static JsonStore? _instance;

  static Future<JsonStore> open() async {
    final cached = _instance;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'synchrobeat'));
    await root.create(recursive: true);
    final store = JsonStore._(root);
    _instance = store;
    return store;
  }

  File _file(String name) => File(p.join(root.path, name));

  Future<List<dynamic>> readList(String name) async {
    final file = _file(name);
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> readMap(String name) async {
    final file = _file(name);
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String name, Object? data) async {
    final file = _file(name);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
  }

  Future<String> subdir(String relPath) async {
    final dir = Directory(p.join(root.path, relPath));
    await dir.create(recursive: true);
    return dir.path;
  }

  String pathOf(String name) => _file(name).path;
}
