import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/session_models.dart';
import '../history/session_providers.dart';
import '../stats/stats_util.dart';

/// Aggregate stats every badge is evaluated against — all derived from the
/// session list (no extra backend call).
class _Stats {
  _Stats({
    required this.totalSessions,
    required this.totalDays,
    required this.longestStreakDays,
    required this.totalVolumeKg,
    required this.totalPrs,
  });

  final int totalSessions;
  final int totalDays;
  final int longestStreakDays;
  final double totalVolumeKg;
  final int totalPrs;

  factory _Stats.from(List<WorkoutSessionSummary> sessions) {
    final days = trainedDays(sessions);
    var vol = 0.0;
    var prs = 0;
    for (final s in sessions) {
      vol += s.totalVolume;
      prs += s.prCount;
    }
    return _Stats(
      totalSessions: sessions.length,
      totalDays: days.length,
      longestStreakDays: longestStreak(days),
      totalVolumeKg: vol,
      totalPrs: prs,
    );
  }
}

/// A badge as shown to the user, with current progress toward its goal.
class _BadgeView {
  _BadgeView({
    required this.emoji,
    required this.name,
    required this.desc,
    required this.unit,
    required this.color,
    required this.current,
    required this.threshold,
    this.decimals = 0,
  });

  final String emoji;
  final String name;
  final String desc;
  final String unit;
  final Color color;
  final double current;
  final double threshold;
  final int decimals;

  bool get unlocked => current >= threshold;
  double get progress => (current / threshold).clamp(0.0, 1.0);

  String _n(double v) => decimals == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(decimals);
  String get progressText => unlocked ? '已解锁' : '${_n(current)} / ${_n(threshold)} $unit';
}

const _indigo = Color(0xFF6366F1);
const _red = Color(0xFFEF4444);
const _teal = Color(0xFF14B8A6);
const _gold = Color(0xFFF59E0B);
const _purple = Color(0xFFA855F7);

List<_BadgeView> _buildBadges(_Stats s) {
  return [
    // 打卡启程 / 连续
    _BadgeView(emoji: '🎯', name: '初次启程', desc: '完成第一次训练', unit: '次', color: _indigo,
        current: s.totalSessions.toDouble(), threshold: 1),
    _BadgeView(emoji: '⚡', name: '三连击', desc: '连续打卡 3 天', unit: '天', color: _indigo,
        current: s.longestStreakDays.toDouble(), threshold: 3),
    _BadgeView(emoji: '🔥', name: '一周不断', desc: '连续打卡 7 天', unit: '天', color: _red,
        current: s.longestStreakDays.toDouble(), threshold: 7),
    _BadgeView(emoji: '🗓️', name: '月度坚持', desc: '连续打卡 30 天', unit: '天', color: _red,
        current: s.longestStreakDays.toDouble(), threshold: 30),
    // 累计天数
    _BadgeView(emoji: '🏋️', name: '训练达人', desc: '累计打卡 10 天', unit: '天', color: _teal,
        current: s.totalDays.toDouble(), threshold: 10),
    _BadgeView(emoji: '🥉', name: '百炼成钢', desc: '累计打卡 50 天', unit: '天', color: _teal,
        current: s.totalDays.toDouble(), threshold: 50),
    _BadgeView(emoji: '🏅', name: '铁人', desc: '累计打卡 100 天', unit: '天', color: _teal,
        current: s.totalDays.toDouble(), threshold: 100),
    // 累计容量（吨）
    _BadgeView(emoji: '🐘', name: '大力士', desc: '累计举起 5 吨', unit: '吨', color: _gold,
        current: s.totalVolumeKg / 1000, threshold: 5, decimals: 1),
    _BadgeView(emoji: '🚚', name: '力可移山', desc: '累计举起 50 吨', unit: '吨', color: _gold,
        current: s.totalVolumeKg / 1000, threshold: 50, decimals: 1),
    _BadgeView(emoji: '🏔️', name: '撼山之力', desc: '累计举起 200 吨', unit: '吨', color: _gold,
        current: s.totalVolumeKg / 1000, threshold: 200, decimals: 1),
    // 破纪录
    _BadgeView(emoji: '🏆', name: '突破自我', desc: '首次破纪录', unit: '次', color: _purple,
        current: s.totalPrs.toDouble(), threshold: 1),
    _BadgeView(emoji: '👑', name: '纪录收割机', desc: '累计破纪录 10 次', unit: '次', color: _purple,
        current: s.totalPrs.toDouble(), threshold: 10),
    _BadgeView(emoji: '💎', name: '巅峰状态', desc: '累计破纪录 50 次', unit: '次', color: _purple,
        current: s.totalPrs.toDouble(), threshold: 50),
    // 勤奋
    _BadgeView(emoji: '💯', name: '百场传奇', desc: '完成 100 次训练', unit: '次', color: _indigo,
        current: s.totalSessions.toDouble(), threshold: 100),
  ];
}

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('成就徽章 🏅')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (sessions) {
          final badges = _buildBadges(_Stats.from(sessions));
          final unlocked = badges.where((b) => b.unlocked).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionsProvider),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.pad, AppTheme.pad, AppTheme.pad, 0),
                  child: _HeaderBanner(unlocked: unlocked, total: badges.length),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppTheme.pad),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppTheme.gap,
                      mainAxisSpacing: AppTheme.gap,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: badges.length,
                    itemBuilder: (_, i) => _BadgeCard(b: badges[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: const LinearGradient(
          colors: [_gold, Color(0xFFEA580C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('已解锁徽章',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Text('$unlocked / $total',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.b});

  final _BadgeView b;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = b.unlocked;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: on ? b.color.withValues(alpha: 0.10) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: on ? b.color.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.4),
          width: on ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 2),
          Opacity(
            opacity: on ? 1 : 0.3,
            child: Text(b.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 4),
          Text(b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? null : scheme.onSurface.withValues(alpha: 0.6),
              )),
          const Spacer(),
          if (on)
            Text('已解锁', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: b.color))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: b.progress,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
                color: b.color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 3),
            Text(b.progressText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }
}
