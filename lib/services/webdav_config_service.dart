import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// Credentials for a WebDAV server (e.g. NextCloud/ownCloud), stored in the
/// platform keystore/keychain - never in SharedPreferences.
class WebDavConfig {
  final String serverUrl;
  final String username;
  final String appPassword;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
  });
}

class WebDavConfigService {
  static const _storage = FlutterSecureStorage();
  static const String _serverUrlKey = 'webdav_server_url';
  static const String _usernameKey = 'webdav_username';
  static const String _appPasswordKey = 'webdav_app_password';

  Future<WebDavConfig?> getConfig() async {
    final serverUrl = await _storage.read(key: _serverUrlKey);
    final username = await _storage.read(key: _usernameKey);
    final appPassword = await _storage.read(key: _appPasswordKey);

    if (serverUrl == null || serverUrl.isEmpty || username == null || username.isEmpty) {
      return null;
    }

    return WebDavConfig(
      serverUrl: serverUrl,
      username: username,
      appPassword: appPassword ?? '',
    );
  }

  Future<void> saveConfig(WebDavConfig config) async {
    await _storage.write(key: _serverUrlKey, value: config.serverUrl);
    await _storage.write(key: _usernameKey, value: config.username);
    await _storage.write(key: _appPasswordKey, value: config.appPassword);
  }

  Future<void> clearConfig() async {
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _appPasswordKey);
  }

  /// Validates credentials against the server before they're saved.
  Future<bool> testConnection(WebDavConfig config) async {
    try {
      final client = webdav.newClient(
        config.serverUrl,
        user: config.username,
        password: config.appPassword,
      );
      await client.ping();
      return true;
    } catch (e) {
      debugPrint('WebDAV connection test failed: $e');
      return false;
    }
  }
}
