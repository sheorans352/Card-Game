import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { staging, production }

class AppConfig {
  final AppEnvironment environment;
  final bool useMock;

  AppConfig({
    required this.environment,
    required this.useMock,
  });

  factory AppConfig.fromEnvironment() {
    // For now, we manually set this, or use kReleaseMode / --dart-define
    // By default, staging uses Mock for stability during Flutter 3.19 era.
    const isStaging = bool.fromEnvironment('staging', defaultValue: true);
    
    return AppConfig(
      environment: isStaging ? AppEnvironment.staging : AppEnvironment.production,
      useMock: true, // Force mock for now until Supabase is fixed for Web
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
