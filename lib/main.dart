import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'providers/room_provider.dart';

// User provided credentials
const supabaseUrl = 'https://ophamlgpkcfrfmjtpjgm.supabase.co';
const supabaseKey = 'sb_publishable_BEu0MWm9_v2dbmY03hgd-Q_qdmLqoT_';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Handle Initial Link (App Cold Start)
    ref.listen(appLinkStreamProvider, (previous, next) {
      next.whenData((uri) {
        final code = uri.queryParameters['room'];
        if (code != null) {
          ref.read(currentRoomCodeProvider.notifier).state = code;
        }
      });
    });

    // 2. Detect URL parameters for Web
    final roomCode = Uri.base.queryParameters['room'];
    if (roomCode != null && ref.read(currentRoomCodeProvider) == null) {
      Future.delayed(Duration.zero, () {
         ref.read(currentRoomCodeProvider.notifier).state = roomCode;
      });
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minus Card Game',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButtonThemeData().style?.copyWith(
            backgroundColor: MaterialStateProperty.all(Colors.deepPurple),
            foregroundColor: MaterialStateProperty.all(Colors.white),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
