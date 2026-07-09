import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../history/session_providers.dart';
import '../profile/profile_providers.dart';
import '../stats/stats_util.dart';
import '../workout/today_section.dart';

/// The "今天" tab: greeting + today's workout.
class TodayHomePage extends ConsumerWidget {
  const TodayHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = displayName(ref.watch(authUserProvider).value);

    final h = DateTime.now().hour;
    final greet = h < 6
        ? '凌晨好'
        : h < 12
            ? '早上好'
            : h < 14
                ? '中午好'
                : h < 18
                    ? '下午好'
                    : '晚上好';
    final greetEmoji = h < 12 ? '🌅' : (h < 18 ? '☀️' : '🌙');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.pad, 12, AppTheme.pad, AppTheme.pad),
          children: [
            Text('$greetEmoji  $greet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 2),
            Text(display,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.pad),
            const _WeekSummary(),
            const TodaySection(),
          ],
        ),
      ),
    );
  }
}

/// Compact streak / this-week chip on the home; taps through to full stats.
class _WeekSummary extends ConsumerWidget {
  const _WeekSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider).value;
    if (sessions == null || sessions.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final days = trainedDays(sessions);
    final st = streak(days, now);
    final wk = weekCount(days, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.pad),
      child: Material(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => context.push('/stats'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pad, vertical: 12),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    st > 0 ? '连续打卡 $st 天 · 本周 $wk 天' : '本周已打卡 $wk 天',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
