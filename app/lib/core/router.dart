import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/achievements/achievements_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/body/body_page.dart';
import '../features/exercise/exercise.dart';
import '../features/exercise/exercise_detail_page.dart';
import '../features/exercise/exercise_form_page.dart';
import '../features/exercise/exercise_list_page.dart';
import '../features/history/history_page.dart';
import '../features/history/session_detail_page.dart';
import '../features/home/main_shell.dart';
import '../features/profile/profile_edit_page.dart';
import '../features/report/weekly_report_page.dart';
import '../features/stats/stats_page.dart';
import '../features/workout/plan_detail_page.dart';
import '../features/workout/plans_page.dart';
import '../features/workout/quick_workout_page.dart';
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
      GoRoute(path: '/exercises', pageBuilder: (_, s) => _fade(s, const ExerciseListPage())),
      GoRoute(
        path: '/exercise-detail',
        pageBuilder: (_, s) {
          final e = s.extra;
          return _fade(s, e is Exercise ? ExerciseDetailPage(exercise: e) : const ExerciseListPage());
        },
      ),
      GoRoute(
        path: '/exercise-form',
        pageBuilder: (_, s) => _fade(s, ExerciseFormPage(exercise: s.extra is Exercise ? s.extra as Exercise : null)),
      ),
      GoRoute(path: '/plans', pageBuilder: (_, s) => _fade(s, const PlansPage())),
      GoRoute(path: '/quick-workout', pageBuilder: (_, s) => _fade(s, const QuickWorkoutPage())),
      GoRoute(path: '/body', pageBuilder: (_, s) => _fade(s, const BodyPage())),
      GoRoute(path: '/profile-edit', pageBuilder: (_, s) => _fade(s, const ProfileEditPage())),
      GoRoute(path: '/history', pageBuilder: (_, s) => _fade(s, const HistoryPage())),
      GoRoute(path: '/stats', pageBuilder: (_, s) => _fade(s, const StatsPage())),
      GoRoute(path: '/achievements', pageBuilder: (_, s) => _fade(s, const AchievementsPage())),
      GoRoute(path: '/weekly-report', pageBuilder: (_, s) => _fade(s, const WeeklyReportPage())),
      GoRoute(
        path: '/session-detail',
        pageBuilder: (_, s) =>
            _fade(s, s.extra is String ? SessionDetailPage(sessionId: s.extra as String) : const HistoryPage()),
      ),
      GoRoute(
        path: '/plan-detail',
        pageBuilder: (_, s) => _fade(s, s.extra is Plan ? PlanDetailPage(plan: s.extra as Plan) : const PlansPage()),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
    ],
  );
});

/// Pushed pages fade in with a subtle upward slide (tabs stay instant via IndexedStack).
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

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
