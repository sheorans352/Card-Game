import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'providers/room_provider.dart';
import 'config/env_config.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await gameAudio.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start session initialization immediately
    ref.read(sessionProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minus Card Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF062A14),
      ),
      home: const InitializationWrapper(),
    );
  }
}

class InitializationWrapper extends ConsumerWidget {
  const InitializationWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    final roomCode = ref.watch(currentRoomCodeProvider);
    final playerId = ref.watch(localPlayerIdProvider);

    return sessionAsync.when(
      data: (_) {
        if (roomCode != null && playerId != null) {
          // If we have a session, we'll let the HomeScreen handle the redirection
          // or we could push directly here. For simplicity, we'll let HomeScreen
          // check for auto-join in its build method.
          return const HomeScreen();
        }
        return const HomeScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFC7A14C)))),
      error: (_, __) => const HomeScreen(),
    );
  }
}
