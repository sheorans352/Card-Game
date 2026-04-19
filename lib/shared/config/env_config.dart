import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { staging, production }

class AppConfig {
  final AppEnvironment environment;

  static const String supabaseUrl = 'https://ophamlgpkcfrfmjtpjgm.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_BEu0MWm9_v2dbmY03hgd-Q_qdmLqoT_';

  AppConfig({required this.environment});

  /// Detects environment at runtime from the URL hostname.
  ///
  /// Staging:    any Vercel preview URL containing 'staging',
  ///             or localhost / 127.0.0.1 (local dev).
  /// Production: everything else (custom domain, main Vercel deploy).
  factory AppConfig.fromEnvironment() {
    AppEnvironment env = AppEnvironment.production;

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('staging') ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host.startsWith('192.168.')) {
        env = AppEnvironment.staging;
      }
    } else {
      // Native / debug builds always treated as staging
      env = AppEnvironment.staging;
    }

    return AppConfig(environment: env);
  }

  bool get isStaging => environment == AppEnvironment.staging;
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
