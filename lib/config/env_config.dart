import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { staging, production }

class AppConfig {
  final AppEnvironment environment;
  
  static const String supabaseUrl = 'https://ophamlgpkcfrfmjtpjgm.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_BEu0MWm9_v2dbmY03hgd-Q_qdmLqoT_';

  AppConfig({
    required this.environment,
  });

  factory AppConfig.fromEnvironment() {
    const isStaging = bool.fromEnvironment('staging', defaultValue: true);
    
    return AppConfig(
      environment: isStaging ? AppEnvironment.staging : AppEnvironment.production,
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
