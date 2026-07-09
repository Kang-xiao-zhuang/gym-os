import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/home_page.dart';

/// App router. Redirects unauthenticated users to /login and re-runs whenever
/// Supabase's auth state changes (login / logout).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (!loggedIn) return onAuthPage ? null : '/login';
      if (onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
    ],
  );
});

/// Bridges a Stream into a Listenable so GoRouter re-evaluates its redirect.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
