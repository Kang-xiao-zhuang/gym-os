import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/session_providers.dart';
import 'stats_util.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('训练统计 📈')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyView(
              emoji: '📅',
              title: '还没有打卡记录',
              subtitle: '去「今天」完成一次训练，这里就会有数据',
            );
          }
          final now = DateTime.now();
          final days = trainedDays(sessions);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pad),
              children: [
                Row(
                  children: [
                    _Stat(label: '本周打卡', value: '${weekCount(days, now)}', unit: '天', color: const Color(0xFF6366F1)),
                    const SizedBox(width: 10),
                    _Stat(label: '连续打卡', value: '${streak(days, now)}', unit: '天', color: const Color(0xFFEF4444), emoji: '🔥'),
                    const SizedBox(width: 10),
                    _Stat(label: '累计打卡', value: '${days.length}', unit: '天', color: const Color(0xFF14B8A6)),
                  ],
                ),
                const SizedBox(height: 20),
                _Calendar(month: _month, trained: days, now: now, onShift: _shift),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit, required this.color, this.emoji});

  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(emoji == null ? label : '$emoji $label',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  TextSpan(text: ' $unit', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.trained, required this.now, required this.onShift});

  final DateTime month;
  final Set<DateTime> trained;
  final DateTime now;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // Mon=1
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <int?>[...List.filled(firstWeekday - 1, null), for (var d = 1; d <= daysInMonth; d++) d];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.pad),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => onShift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text('${month.year} 年 ${month.month} 月',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              IconButton(onPressed: () => onShift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((w) => Expanded(
                    child: Center(
                        child: Text(w, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          ...List.generate(cells.length ~/ 7, (row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: List.generate(7, (col) {
                  final day = cells[row * 7 + col];
                  return Expanded(child: _dayCell(context, day, scheme));
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, int? day, ColorScheme scheme) {
    if (day == null) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    final isTrained = trained.contains(date);
    final isToday = date == DateTime(now.year, now.month, now.day);
    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isTrained ? scheme.primary : Colors.transparent,
          border: isToday && !isTrained ? Border.all(color: scheme.primary, width: 1.5) : null,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isTrained || isToday ? FontWeight.w700 : FontWeight.w400,
            color: isTrained ? Colors.white : (isToday ? scheme.primary : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
