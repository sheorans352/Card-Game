import 'package:go_router/go_router.dart';
import 'screens/hub_screen.dart';
import 'games/minus/screens/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HubScreen(),
    ),
    GoRoute(
      path: '/minus',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
