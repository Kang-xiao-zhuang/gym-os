import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/session_models.dart';
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
                const SizedBox(height: 16),
                const _InsightCards(),
                const SizedBox(height: 4),
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

String _fmtKg(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// "复盘" — actionable coaching cards derived from the whole history:
/// biggest recent gain, this-month body-part balance, possible plateaus.
class _InsightCards extends ConsumerWidget {
  const _InsightCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsProvider);
    final ins = async.value;
    if (ins == null || ins.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text('复盘', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        if (ins.biggestGain != null) ...[
          _GainCard(gain: ins.biggestGain!),
          const SizedBox(height: 10),
        ],
        if (ins.bodyParts.isNotEmpty) ...[
          _BalanceCard(parts: ins.bodyParts),
          const SizedBox(height: 10),
        ],
        if (ins.plateaus.isNotEmpty) ...[
          _PlateauCard(plateaus: ins.plateaus),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GainCard extends StatelessWidget {
  const _GainCard({required this.gain});
  final Gain gain;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    return _insightBox(
      color: green,
      child: Row(
        children: [
          const Text('📈', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('本月进步最大', style: TextStyle(fontSize: 12, color: green, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${gain.exerciseName}  ${_fmtKg(gain.fromWeight)} → ${_fmtKg(gain.toWeight)} kg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('+${_fmtKg(gain.delta)}kg',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: green)),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.parts});
  final List<BodyPartLoad> parts;

  @override
  Widget build(BuildContext context) {
    final maxSets = parts.map((p) => p.sets).fold<int>(1, (a, b) => b > a ? b : a);
    final lowest = parts.reduce((a, b) => a.sets <= b.sets ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return _insightBox(
      color: const Color(0xFF6366F1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('🧭 ', style: TextStyle(fontSize: 14)),
            Text('本月部位分布', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          ...parts.map((p) {
            final st = bodyPartStyle(p.bodyPart);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Text(st.emoji, style: const TextStyle(fontSize: 15))),
                  SizedBox(width: 34, child: Text(p.bodyPart, style: const TextStyle(fontSize: 12.5))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.sets / maxSets,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: st.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${p.sets} 组', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Text('💡 ${lowest.bodyPart}练得最少（${lowest.sets} 组），别落下',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _PlateauCard extends StatelessWidget {
  const _PlateauCard({required this.plateaus});
  final List<Plateau> plateaus;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return _insightBox(
      color: amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('⚠️ ', style: TextStyle(fontSize: 14)),
            Text('可能停滞', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
          ]),
          const SizedBox(height: 6),
          ...plateaus.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${p.exerciseName} · 近 ${p.sessions} 次停在 ${_fmtKg(p.weight)}kg，该冲一把或换变式',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5)),
              )),
        ],
      ),
    );
  }
}

Widget _insightBox({required Color color, required Widget child}) => Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: child,
      ),
    );

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
    final style = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
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
    final style = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
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
