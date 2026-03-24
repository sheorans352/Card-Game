import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { staging, production }

class AppConfig {
  final AppEnvironment environment;
  final bool useMock;
  
  static const String supabaseUrl = 'https://ophamlgpkcfrfmjtpjgm.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_BEu0MWm9_v2dbmY03hgd-Q_qdmLqoT_';

  AppConfig({
    required this.environment,
    required this.useMock,
  });

  factory AppConfig.fromEnvironment() {
    // Stage is default, can toggle via dart-define if needed
    const isStaging = bool.fromEnvironment('staging', defaultValue: true);
    
    return AppConfig(
      environment: isStaging ? AppEnvironment.staging : AppEnvironment.production,
      useMock: false, // Switching to Supabase for Multiplayer Beta
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
