import 'package:go_router/go_router.dart';
import 'screens/hub_screen.dart';
import 'games/minus/screens/home_screen.dart';
import 'games/matka/screens/home_screen.dart';
import 'games/matka/screens/lobby_screen.dart';
import 'games/matka/screens/game_table_screen.dart';
import 'screens/blog_list_screen.dart';
import 'screens/blog_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HubScreen(),
    ),
    GoRoute(
      path: '/blogs',
      builder: (context, state) => const BlogListScreen(),
      routes: [
        GoRoute(
          path: ':slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return BlogDetailScreen(slug: slug);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/minus',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/matka',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return MatkaHomeScreen(prefilledCode: code);
      },
      routes: [
        GoRoute(
          path: 'lobby/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return MatkaLobbyScreen(roomId: roomId);
          },
        ),
        GoRoute(
          path: 'table/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return MatkaGameTableScreen(roomId: roomId);
          },
        ),
      ],
    ),
  ],
);
