import 'dart:convert';
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
  static const String _configKey = 'webdav_config_v2';
  static const String _serverUrlKey = 'webdav_server_url';
  static const String _usernameKey = 'webdav_username';
  static const String _appPasswordKey = 'webdav_app_password';

  Future<WebDavConfig?> getConfig() async {
    final raw = await _storage.read(key: _configKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map;
      return WebDavConfig(
          serverUrl: data['serverUrl'] as String,
          username: data['username'] as String,
          appPassword: data['appPassword'] as String);
    }
    final serverUrl = await _storage.read(key: _serverUrlKey);
    final username = await _storage.read(key: _usernameKey);
    final appPassword = await _storage.read(key: _appPasswordKey);

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        username == null ||
        username.isEmpty) {
      return null;
    }

    return WebDavConfig(
      serverUrl: serverUrl,
      username: username,
      appPassword: appPassword ?? '',
    );
  }

  void validate(WebDavConfig config) {
    final url = Uri.tryParse(config.serverUrl);
    if (url == null ||
        !['http', 'https'].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw const FormatException(
          'Enter a full HTTP or HTTPS WebDAV URL without credentials or a query.');
    }
    if (config.username.isEmpty ||
        config.username.contains(':') ||
        config.appPassword.isEmpty) {
      throw const FormatException('Enter a username and app password.');
    }
  }

  Future<void> saveConfig(WebDavConfig config) async {
    validate(config);
    // One encrypted record avoids mixing credentials from two different servers
    // if a configuration update is interrupted.
    await _storage.write(
        key: _configKey,
        value: jsonEncode({
          'serverUrl': config.serverUrl,
          'username': config.username,
          'appPassword': config.appPassword,
        }));
  }

  Future<void> clearConfig() async {
    await _storage.delete(key: _configKey);
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _appPasswordKey);
  }

  /// Validates credentials against the server before they're saved.
  Future<bool> testConnection(WebDavConfig config) async {
    try {
      validate(config);
      final client = webdav.newClient(
        config.serverUrl,
        user: config.username,
        password: config.appPassword,
      )
        ..auth =
            webdav.BasicAuth(user: config.username, pwd: config.appPassword)
        ..setConnectTimeout(5000)
        ..setReceiveTimeout(5000);
      await client.ping().timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint('WebDAV connection test failed: $e');
      return false;
    }
  }
}
