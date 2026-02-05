import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_server.dart';

/// Service for persisting saved servers to local storage.
class ServerStorageService {
  static const _key = 'saved_servers';
  static const _maxServers = 10;

  final SharedPreferences _prefs;

  ServerStorageService(this._prefs);

  /// Creates a ServerStorageService instance.
  static Future<ServerStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ServerStorageService(prefs);
  }

  /// Loads the list of saved servers from local storage.
  Future<List<SavedServer>> loadServers() async {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => SavedServer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Saves the list of servers to local storage.
  /// Limits to [_maxServers] entries, keeping favorites and most recent.
  Future<void> saveServers(List<SavedServer> servers) async {
    // Sort: favorites first, then by lastConnected descending
    final sorted = List<SavedServer>.from(servers)
      ..sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        return b.lastConnected.compareTo(a.lastConnected);
      });

    // Limit to max servers
    final limited = sorted.take(_maxServers).toList();

    final jsonList = limited.map((s) => s.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_key, jsonString);
  }

  /// Adds or updates a server in the saved list.
  /// If server with same host:port exists, updates lastConnected.
  /// Returns the updated list.
  Future<List<SavedServer>> addOrUpdateServer(
    List<SavedServer> currentServers,
    SavedServer server,
  ) async {
    final existingIndex = currentServers.indexWhere(
      (s) => s.host == server.host && s.port == server.port,
    );

    List<SavedServer> updated;
    if (existingIndex >= 0) {
      // Update existing server's lastConnected, preserve favorite status
      final existing = currentServers[existingIndex];
      updated = List<SavedServer>.from(currentServers);
      updated[existingIndex] = server.copyWith(
        id: existing.id,
        isFavorite: existing.isFavorite,
      );
    } else {
      // Add new server
      updated = [server, ...currentServers];
    }

    await saveServers(updated);
    return await loadServers(); // Return the trimmed/sorted list
  }

  /// Removes a server from the saved list.
  Future<List<SavedServer>> removeServer(
    List<SavedServer> currentServers,
    String serverId,
  ) async {
    final updated = currentServers.where((s) => s.id != serverId).toList();
    await saveServers(updated);
    return updated;
  }

  /// Toggles the favorite status of a server.
  Future<List<SavedServer>> toggleFavorite(
    List<SavedServer> currentServers,
    String serverId,
  ) async {
    final updated = currentServers.map((s) {
      if (s.id == serverId) {
        return s.copyWith(isFavorite: !s.isFavorite);
      }
      return s;
    }).toList();
    await saveServers(updated);
    return await loadServers(); // Return re-sorted list
  }
}
