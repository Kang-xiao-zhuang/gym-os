import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/body/body_page.dart';
import '../features/exercise/exercise.dart';
import '../features/exercise/exercise_detail_page.dart';
import '../features/exercise/exercise_form_page.dart';
import '../features/exercise/exercise_list_page.dart';
import '../features/home/main_shell.dart';
import '../features/workout/plan_detail_page.dart';
import '../features/workout/plans_page.dart';
import '../features/workout/workout_models.dart';

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
      GoRoute(path: '/', builder: (_, _) => const MainShell()),
      GoRoute(path: '/exercises', builder: (_, _) => const ExerciseListPage()),
      GoRoute(
        path: '/exercise-detail',
        builder: (_, state) {
          final e = state.extra;
          return e is Exercise ? ExerciseDetailPage(exercise: e) : const ExerciseListPage();
        },
      ),
      GoRoute(
        path: '/exercise-form',
        builder: (_, state) => ExerciseFormPage(exercise: state.extra is Exercise ? state.extra as Exercise : null),
      ),
      GoRoute(path: '/plans', builder: (_, _) => const PlansPage()),
      GoRoute(path: '/body', builder: (_, _) => const BodyPage()),
      GoRoute(
        path: '/plan-detail',
        builder: (_, state) => state.extra is Plan ? PlanDetailPage(plan: state.extra as Plan) : const PlansPage(),
      ),
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
