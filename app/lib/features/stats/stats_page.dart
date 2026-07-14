import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  int _year = DateTime.now().year;

  void _shiftYear(int delta) => setState(() => _year += delta);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练统计 📈'),
        actions: [
          IconButton(
            tooltip: '生成周报',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => context.push('/weekly-report'),
          ),
        ],
      ),
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
          final loads = daySetLoads(sessions);
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
                _YearHeatmap(year: _year, loads: loads, now: now, trainedInYear: yearCount(days, _year), onShiftYear: _shiftYear),
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

/// GitHub-style yearly check-in heatmap: 7 rows (Mon→Sun) × ~53 week columns,
/// each cell shaded by that day's training load (total sets).
class _YearHeatmap extends StatefulWidget {
  const _YearHeatmap({
    required this.year,
    required this.loads,
    required this.now,
    required this.trainedInYear,
    required this.onShiftYear,
  });

  final int year;
  final Map<DateTime, int> loads;
  final DateTime now;
  final int trainedInYear;
  final ValueChanged<int> onShiftYear;

  @override
  State<_YearHeatmap> createState() => _YearHeatmapState();
}

class _YearHeatmapState extends State<_YearHeatmap> {
  static const double _cell = 14;
  static const double _gap = 3;
  static const double _colW = _cell + _gap;
  static const double _monthLabelH = 18;

  final _scroll = ScrollController();

  static const List<Color> _greens = [
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];

  late List<List<DateTime>> _columns;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _build();
    // Open near "today" for the current year so recent weeks are visible.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void didUpdateWidget(covariant _YearHeatmap old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) _build();
  }

  void _build() {
    _today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final jan1 = DateTime(widget.year, 1, 1);
    final dec31 = DateTime(widget.year, 12, 31);
    final start = jan1.subtract(Duration(days: jan1.weekday - 1)); // Monday on/before Jan 1
    final cols = <List<DateTime>>[];
    var cur = start;
    while (!cur.isAfter(dec31)) {
      cols.add(List.generate(7, (i) => cur.add(Duration(days: i))));
      cur = cur.add(const Duration(days: 7));
    }
    _columns = cols;
  }

  void _scrollToToday() {
    if (!_scroll.hasClients || widget.year != widget.now.year) return;
    final startMonday = _columns.first.first;
    final col = _today.difference(startMonday).inDays ~/ 7;
    final target = (col * _colW - 120).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.pad),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => widget.onShiftYear(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text('${widget.year} 年 · 打卡 ${widget.trainedInYear} 天',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              IconButton(
                onPressed: widget.year < widget.now.year ? () => widget.onShiftYear(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _weekdayLabels(scheme),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _monthLabels(scheme),
                      Row(children: _columns.map((w) => _weekColumn(w, scheme)).toList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _legend(scheme),
        ],
      ),
    );
  }

  Widget _weekdayLabels(ColorScheme scheme) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final style = TextStyle(fontSize: 10, color: Colors.grey.shade500);
    return Column(
      children: [
        const SizedBox(height: _monthLabelH),
        ...List.generate(7, (i) => SizedBox(
              height: _colW,
              child: Align(
                alignment: Alignment.centerRight,
                child: i.isEven ? Text(names[i], style: style) : null,
              ),
            )),
      ],
    );
  }

  Widget _monthLabels(ColorScheme scheme) {
    final style = TextStyle(fontSize: 10, color: Colors.grey.shade500);
    var lastMonth = -1;
    final labels = <Widget>[];
    for (final week in _columns) {
      final monday = week.first;
      String text = '';
      if (monday.year == widget.year && monday.month != lastMonth) {
        text = '${monday.month}月';
        lastMonth = monday.month;
      }
      labels.add(SizedBox(
        width: _colW,
        height: _monthLabelH,
        child: text.isEmpty
            ? null
            : OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: 40,
                child: Text(text, style: style, maxLines: 1),
              ),
      ));
    }
    return Row(children: labels);
  }

  Widget _weekColumn(List<DateTime> week, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(right: _gap),
      child: Column(children: week.map((d) => _cellFor(d, scheme)).toList()),
    );
  }

  Widget _cellFor(DateTime d, ColorScheme scheme) {
    final inYear = d.year == widget.year;
    if (!inYear) return const SizedBox(width: _cell, height: _colW);

    final future = d.isAfter(_today);
    final sets = widget.loads[d] ?? 0;
    final lvl = heatLevel(sets);
    Color color;
    if (future) {
      color = scheme.surfaceContainerHighest.withValues(alpha: 0.2);
    } else if (lvl == 0) {
      color = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    } else {
      color = _greens[lvl - 1];
    }
    final isToday = d == _today;
    final tip = future
        ? null
        : '${d.month}月${d.day}日 · ${sets > 0 ? '$sets 组' : '未训练'}';
    final box = Container(
      width: _cell,
      height: _cell,
      margin: const EdgeInsets.only(bottom: _gap),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: isToday ? Border.all(color: scheme.primary, width: 1.3) : null,
      ),
    );
    return tip == null ? box : Tooltip(message: tip, waitDuration: const Duration(milliseconds: 300), child: box);
  }

  Widget _legend(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('少', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(width: 6),
        _swatch(scheme.surfaceContainerHighest.withValues(alpha: 0.6)),
        for (final c in _greens) _swatch(c),
        const SizedBox(width: 6),
        Text('多', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _swatch(Color c) => Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      );
}
