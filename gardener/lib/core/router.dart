import 'package:go_router/go_router.dart';
import 'package:gardener/ui/screens/home_screen.dart';
import 'package:gardener/ui/screens/auth_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(
      path: '/link',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        // Pass token to HomeScreen to handle the actual linking
        return HomeScreen(initialToken: token);
      },
    ),
  ],
);
