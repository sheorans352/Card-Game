import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!AppConfig.useMock) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    // Force clear local storage to prevent Mock ghosts
    html.window.localStorage.clear();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minus Card Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const Scaffold(
        body: Stack(
          children: [
            HomeScreen(),
            Positioned(
              bottom: 10,
              right: 10,
              child: _EngineIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineIndicator extends ConsumerWidget {
  const _EngineIndicator();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.useMock ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config.useMock ? 'MOCK ENGINE' : 'SUPABASE LIVE',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
