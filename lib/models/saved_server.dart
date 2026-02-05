/// A saved server entry for connection history.
class SavedServer {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool isFavorite;
  final DateTime lastConnected;

  const SavedServer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.isFavorite = false,
    required this.lastConnected,
  });

  /// Creates a SavedServer from JSON map.
  factory SavedServer.fromJson(Map<String, dynamic> json) {
    return SavedServer(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      isFavorite: json['isFavorite'] as bool? ?? false,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
    );
  }

  /// Converts the SavedServer to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'isFavorite': isFavorite,
      'lastConnected': lastConnected.toIso8601String(),
    };
  }

  /// Creates a copy of this SavedServer with the given fields replaced.
  SavedServer copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? isFavorite,
    DateTime? lastConnected,
  }) {
    return SavedServer(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      isFavorite: isFavorite ?? this.isFavorite,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedServer &&
        other.id == id &&
        other.name == name &&
        other.host == host &&
        other.port == port &&
        other.isFavorite == isFavorite &&
        other.lastConnected == lastConnected;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, host, port, isFavorite, lastConnected);
  }

  @override
  String toString() {
    return 'SavedServer(id: $id, name: $name, host: $host, port: $port, '
        'isFavorite: $isFavorite, lastConnected: $lastConnected)';
  }
}
