import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../exercise/exercise.dart';
import '../exercise/exercise_providers.dart';
import '../history/session_providers.dart';
import '../workout/quick_workout_page.dart';
import 'calendar_models.dart';
import 'calendar_providers.dart';
import 'next_up_card.dart';

/// Month calendar ("训练历"): a real calendar grid with large cells that show
/// each day's exercises inline (Google-Calendar style), plus a consistency
/// summary. Tap a day for the full breakdown.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _month;
  int? _selectedDay; // 展开的那天(就地下拉,而非弹窗)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String get _monthKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) => setState(() {
        _month = DateTime(_month.year, _month.month + months);
        _selectedDay = null;
      });

  static const _week = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(calendarProvider(_monthKey));
    return Scaffold(
      appBar: AppBar(title: const Text('训练历')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(calendarProvider(_monthKey));
          ref.invalidate(sessionsProvider);
          ref.invalidate(nextUpProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.pad, 8, AppTheme.pad, 24),
          children: [
            _monthSwitcher(context),
            const SizedBox(height: AppTheme.gap),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.only(top: 90), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: Text('加载失败：$e', style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ),
              data: (days) => _content(context, days),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSwitcher(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Center(child: Text('${_month.year} 年 ${_month.month} 月', style: Theme.of(context).textTheme.titleLarge))),
        IconButton(onPressed: _isCurrentMonth ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
      ],
    );
  }

  Widget _content(BuildContext context, List<CalendarDay> days) {
    final byDay = {for (final d in days) d.date.day: d};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NextUpCard(),
        const SizedBox(height: AppTheme.gap),
        _summaryCard(context, days),
        const SizedBox(height: AppTheme.gap),
        _weekHeader(context),
        const SizedBox(height: 4),
        _grid(context, byDay),
        const SizedBox(height: AppTheme.pad),
        _legend(context),
      ],
    );
  }

  Widget _legend(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final bp in kLegendParts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: bodyPartColor(bp), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(bp, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ]),
      ],
    );
  }

  // ---- 本月战绩 ----
  Widget _summaryCard(BuildContext context, List<CalendarDay> days) {
    final scheme = Theme.of(context).colorScheme;
    final trainedDays = days.length;
    final totalVol = days.fold<double>(0, (a, d) => a + d.volume);
    final volLabel = totalVol >= 1000 ? '${(totalVol / 1000).toStringAsFixed(1)}t' : '${totalVol.toStringAsFixed(0)}kg';
    final sessions = ref.watch(sessionsProvider).value;
    final dates = sessions?.map((s) => s.when).toList() ?? const <DateTime>[];
    final streak = _streak(dates);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Row(
              children: [
                _stat(context, '$trainedDays', '本月练了(天)'),
                _divider(scheme),
                _stat(context, '$streak', '当前连续(天)', highlight: streak > 0),
                _divider(scheme),
                _stat(context, volLabel, '本月总容量'),
              ],
            ),
            if (sessions != null) ...[
              const SizedBox(height: 12),
              _cadenceLine(context, dates),
            ],
          ],
        ),
      ),
    );
  }

  /// 本周训练次数 + 距上次训练天数——比 streak 更当下、更可操作。
  Widget _cadenceLine(BuildContext context, List<DateTime> dates) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1)); // 本周一
    final dayset = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    final thisWeek = dayset.where((d) => !d.isBefore(weekStart) && !d.isAfter(today)).length;
    int? daysSince;
    if (dayset.isNotEmpty) {
      final last = dayset.reduce((a, b) => a.isAfter(b) ? a : b);
      daysSince = today.difference(last).inDays;
    }
    final restText = daysSince == null
        ? '还没开始记录'
        : daysSince == 0
            ? '今天已经练了 💪'
            : '已 $daysSince 天没练';
    final warn = daysSince != null && daysSince >= 3;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 15, color: scheme.primary),
          const SizedBox(width: 4),
          Text('本周 $thisWeek 次', style: TextStyle(fontSize: 12.5, color: scheme.onSurface, fontWeight: FontWeight.w600)),
          Text('  ·  ', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          Text(restText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: warn ? scheme.error : scheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme s) => Container(width: 1, height: 32, color: s.outlineVariant.withValues(alpha: 0.5));

  Widget _stat(BuildContext context, String value, String label, {bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: highlight ? scheme.primary : scheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _weekHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(_week[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: i >= 5 ? scheme.primary : scheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  // ---- 大格子月历(按周排;选中那天在本周行下方就地展开)----
  Widget _grid(BuildContext context, Map<int, CalendarDay> byDay) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1; // Mon-first
    final weeks = <List<int?>>[];
    var d = 1 - leading;
    while (d <= daysInMonth) {
      final wk = <int?>[];
      for (var i = 0; i < 7; i++) {
        wk.add((d >= 1 && d <= daysInMonth) ? d : null);
        d++;
      }
      weeks.add(wk);
    }
    final sel = _selectedDay;
    return Column(
      children: [
        for (final wk in weeks) ...[
          SizedBox(
            height: 104,
            child: Row(
              children: [
                for (final dn in wk)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: dn == null ? const SizedBox() : _cell(context, dn, byDay[dn]),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: (sel != null && wk.contains(sel) && byDay[sel] != null)
                ? _dayDetail(context, byDay[sel]!)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, int day, CalendarDay? data) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday = _month.year == now.year && _month.month == now.month && day == now.day;
    final trained = data != null && data.exercises.isNotEmpty;
    final selected = _selectedDay == day;

    return GestureDetector(
      onTap: trained ? () => setState(() => _selectedDay = selected ? null : day) : null,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.16)
                  : (trained ? scheme.primary.withValues(alpha: 0.06) : scheme.surfaceContainerHighest.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (selected || isToday) ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.8 : (isToday ? 1.6 : 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$day',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 2),
                if (trained)
                  Expanded(
                    child: ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _dayChips(context, data),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trained && data.prCount > 0)
            const Positioned(top: 1, right: 2, child: Text('⭐', style: TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  /// Up to 3 exercise chips per cell, then a "+N" overflow line.
  List<Widget> _dayChips(BuildContext context, CalendarDay data) {
    final scheme = Theme.of(context).colorScheme;
    const maxShown = 3;
    final show = data.exercises.take(maxShown).toList();
    final widgets = <Widget>[
      for (final ex in show)
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: bodyPartColor(ex.bodyPart).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(3),
            border: Border(left: BorderSide(color: bodyPartColor(ex.bodyPart), width: 2)),
          ),
          child: Text(
            ex.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, height: 1.1, fontWeight: FontWeight.w500),
          ),
        ),
    ];
    if (data.exercises.length > maxShown) {
      widgets.add(Text('+${data.exercises.length - maxShown}',
          style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)));
    }
    return widgets;
  }

  // ---- 某天详情:就地下拉面板(完整动作 + 组数)----
  Widget _dayDetail(BuildContext context, CalendarDay d) {
    final scheme = Theme.of(context).colorScheme;
    final meta = <String>[];
    if (d.durationMinutes != null) meta.add('${d.durationMinutes} 分钟');
    meta.add('${d.sets} 组');
    if (d.volume > 0) meta.add('${d.volume.toStringAsFixed(0)} kg 容量');
    if (d.prCount > 0) meta.add('⭐ ${d.prCount} 个 PR');
    return TweenAnimationBuilder<double>(
      key: ValueKey(d.date.day),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${d.date.month} 月 ${d.date.day} 日 · 练了这些',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              InkWell(
                onTap: () => setState(() => _selectedDay = null),
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(meta.join(' · '), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(height: 8),
          for (var i = 0; i < d.exercises.length; i++) ...[
            if (i > 0) Divider(height: 14, color: scheme.outlineVariant.withValues(alpha: 0.4)),
            Row(
              children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: bodyPartColor(d.exercises[i].bodyPart), shape: BoxShape.circle)),
                Expanded(child: Text(d.exercises[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Text(d.exercises[i].setsLabel, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _repeatWorkout(d),
              icon: const Icon(Icons.replay),
              label: const Text('再练一次'),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Prefill a fresh quick workout with this day's exercises.
  Future<void> _repeatWorkout(CalendarDay d) async {
    final rootNav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final all = await ref.read(exerciseListProvider.future);
    final ids = d.exercises.map((e) => e.exerciseId).toSet();
    final picked = <Exercise>[for (final e in all) if (ids.contains(e.id)) e];
    if (picked.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('这些动作在动作库里找不到了')));
      return;
    }
    rootNav.push(MaterialPageRoute(builder: (_) => QuickWorkoutPage(initialExercises: picked)));
  }

  int _streak(List<DateTime> whenList) {
    final set = whenList.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!set.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!set.contains(cursor)) return 0;
    }
    var n = 0;
    while (set.contains(cursor)) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }
}
