import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// DDNS service for VCR Agent.
///
/// Provides external IP detection and Duck DNS update functionality.
/// Supports periodic automatic DNS updates.
class DdnsService {
  /// Duck DNS domain (without .duckdns.org suffix)
  final String? domain;

  /// Duck DNS API token
  final String? token;

  /// WebSocket server port (for logging purposes)
  final int port;

  /// Whether to suppress log output
  final bool quiet;

  /// Timer for periodic DNS updates
  Timer? _updateTimer;

  /// Cached external IP address
  String? _cachedExternalIp;

  /// HTTP client for API requests
  HttpClient? _httpClient;

  /// Whether DDNS is configured
  bool get isConfigured => domain != null && token != null;

  /// Get the cached external IP (call getExternalIp() first)
  String? get externalIp => _cachedExternalIp;

  DdnsService({
    this.domain,
    this.token,
    this.port = 8765,
    this.quiet = false,
  });

  /// Get the external IP address using ipify.org API.
  ///
  /// Returns the external IP address as a string, or null if the request fails.
  Future<String?> getExternalIp() async {
    _httpClient ??= HttpClient();

    try {
      final request = await _httpClient!.getUrl(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        _cachedExternalIp = json['ip'] as String?;
        return _cachedExternalIp;
      } else {
        _log('Failed to get external IP: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Failed to get external IP: $e');
      return null;
    }
  }

  /// Update DNS record using Duck DNS API.
  ///
  /// Parameters:
  /// - [domainOverride]: Override the configured domain
  /// - [tokenOverride]: Override the configured token
  /// - [ip]: IP address to update (if null, Duck DNS will auto-detect)
  ///
  /// Returns true if the update was successful, false otherwise.
  Future<bool> updateDns({
    String? domainOverride,
    String? tokenOverride,
    String? ip,
  }) async {
    final effectiveDomain = domainOverride ?? domain;
    final effectiveToken = tokenOverride ?? token;

    if (effectiveDomain == null || effectiveToken == null) {
      _log('DDNS not configured: missing domain or token');
      return false;
    }

    _httpClient ??= HttpClient();

    try {
      // Extract domain name without .duckdns.org suffix if present
      final cleanDomain = effectiveDomain.replaceAll('.duckdns.org', '');

      // Build Duck DNS update URL
      final uri = Uri.https('www.duckdns.org', '/update', {
        'domains': cleanDomain,
        'token': effectiveToken,
        if (ip != null) 'ip': ip,
      });

      final request = await _httpClient!.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final success = body.trim().toUpperCase() == 'OK';

        if (success) {
          _log('DDNS updated: ws://$cleanDomain.duckdns.org:$port');
          return true;
        } else {
          _log('DDNS update failed: $body');
          return false;
        }
      } else {
        _log('DDNS update failed: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log('DDNS update failed: $e');
      return false;
    }
  }

  /// Start periodic DNS updates.
  ///
  /// Updates DNS every 5 minutes. Performs an initial update immediately.
  /// Returns true if DDNS is configured and initial update was attempted.
  Future<bool> startPeriodicUpdate() async {
    if (!isConfigured) {
      _log('DDNS periodic update not started: not configured');
      return false;
    }

    // Stop any existing timer
    _updateTimer?.cancel();

    // Perform initial update
    await updateDns();

    // Start periodic timer (5 minutes)
    _updateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => updateDns(),
    );

    _log('DDNS periodic update started (every 5 minutes)');
    return true;
  }

  /// Stop periodic DNS updates.
  void stopPeriodicUpdate() {
    if (_updateTimer != null) {
      _updateTimer!.cancel();
      _updateTimer = null;
      _log('DDNS periodic update stopped');
    }
  }

  /// Dispose all resources.
  void dispose() {
    stopPeriodicUpdate();
    _httpClient?.close();
    _httpClient = null;
  }

  void _log(String message) {
    if (quiet) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[$timestamp] $message');
  }
}
