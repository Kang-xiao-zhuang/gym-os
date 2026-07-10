import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'body_providers.dart';
import 'goal_provider.dart';
import 'body_repository.dart';
import 'measurement.dart';

class _Metric {
  const _Metric(this.key, this.label, this.emoji, this.unit, this.color);
  final String key;
  final String label;
  final String emoji;
  final String unit;
  final Color color;
}

const _metrics = [
  _Metric('weight', '体重', '⚖️', 'kg', Color(0xFF14B8A6)),
  _Metric('bodyFat', '体脂', '🔥', '%', Color(0xFFEF4444)),
  _Metric('waist', '腰围', '📏', 'cm', Color(0xFFF97316)),
  _Metric('chest', '胸围', '🫁', 'cm', Color(0xFF6366F1)),
  _Metric('hip', '臀围', '🍑', 'cm', Color(0xFFEC4899)),
  _Metric('armLeft', '手臂', '💪', 'cm', Color(0xFF3B82F6)),
  _Metric('thighLeft', '大腿', '🦵', 'cm', Color(0xFFA855F7)),
];

class BodyPage extends ConsumerStatefulWidget {
  const BodyPage({super.key});

  @override
  ConsumerState<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends ConsumerState<BodyPage> {
  String _metricKey = 'weight';

  Future<void> _editGoal() async {
    final current = ref.read(goalWeightProvider);
    final c = TextEditingController(text: current?.toStringAsFixed(1) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('设定目标体重 🎯'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '目标体重 kg', hintText: '例如：70'),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () {
                ref.read(goalWeightProvider.notifier).set(null);
                Navigator.pop(context, false);
              },
              child: const Text('清除'),
            ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(c.text.trim());
      if (v != null) ref.read(goalWeightProvider.notifier).set(v);
    }
  }

  Future<void> _record() async {
    final fields = {for (final m in _metrics) m.key: TextEditingController()};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('记录身体数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _metrics
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: fields[m.key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: '${m.emoji} ${m.label} ${m.unit}'),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final body = <String, dynamic>{};
    fields.forEach((k, c) {
      final v = double.tryParse(c.text.trim());
      if (v != null) body[k] = v;
    });
    if (body.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少填一项')));
      return;
    }
    try {
      await BodyRepository.create(body);
      ref.invalidate(measurementsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(measurementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('身体数据 📊')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _record,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记录'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              emoji: '📊',
              title: '还没有身体数据',
              subtitle: '记录第一条，开始追踪进度',
              actionLabel: '记录',
              onAction: _record,
            );
          }
          final withData = _metrics.where((m) => items.any((e) => e.valueOf(m.key) != null)).toList();
          if (_metricKey != 'all' && !withData.any((m) => m.key == _metricKey) && withData.isNotEmpty) {
            _metricKey = withData.first.key;
          }
          final isAll = _metricKey == 'all';
          final selected = isAll
              ? withData.first
              : _metrics.firstWhere((m) => m.key == _metricKey, orElse: () => withData.first);
          final series = items.where((e) => e.valueOf(selected.key) != null).toList();

          final goal = ref.watch(goalWeightProvider);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(measurementsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pad),
              children: [
                _GoalHero(
                  weights: items.where((e) => e.weight != null).toList(),
                  goal: goal,
                  onEdit: _editGoal,
                ),
                const SizedBox(height: 20),
                Text('  趋势', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: withData.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ChoiceChip(
                          label: const Text('📊 全部'),
                          selected: isAll,
                          selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.18),
                          onSelected: (_) => setState(() => _metricKey = 'all'),
                        );
                      }
                      final m = withData[i - 1];
                      return ChoiceChip(
                        label: Text('${m.emoji} ${m.label}'),
                        selected: m.key == _metricKey,
                        selectedColor: m.color.withValues(alpha: 0.18),
                        onSelected: (_) => setState(() => _metricKey = m.key),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (isAll) _CompositeChart(items: items, metrics: withData) else _TrendChart(metric: selected, series: series),
                const SizedBox(height: 20),
                Text('  各项指标', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _MetricCards(items: items, metrics: withData),
                const SizedBox(height: 20),
                Text('  历史记录', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...items.reversed.map((m) => _HistoryTile(
                      m: m,
                      onDelete: () async {
                        await BodyRepository.delete(m.id);
                        ref.invalidate(measurementsProvider);
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Teal gradient headline: current weight + delta, and a goal ring if a target
/// weight is set (progress from start weight → target).
class _GoalHero extends StatelessWidget {
  const _GoalHero({required this.weights, required this.goal, required this.onEdit});

  final List<Measurement> weights;
  final double? goal;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final current = weights.isNotEmpty ? weights.last.weight : null;
    double? delta;
    if (weights.length >= 2) delta = weights.last.weight! - weights[weights.length - 2].weight!;

    double? progress;
    if (goal != null && current != null && weights.isNotEmpty) {
      final start = weights.first.weight!;
      if ((start - goal!).abs() < 0.01) {
        progress = 1;
      } else if (goal! < start) {
        progress = (start - current) / (start - goal!);
      } else {
        progress = (current - start) / (goal! - start);
      }
      progress = progress.clamp(0.0, 1.0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF14B8A6).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          if (progress != null)
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: v,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            )
          else
            const Text('⚖️', style: TextStyle(fontSize: 44)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前体重', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(current != null ? '${current.toStringAsFixed(1)} kg' : '— kg',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                if (delta != null) ...[
                  const SizedBox(height: 4),
                  Text('${delta <= 0 ? '↓ 掉了' : '↑ 涨了'} ${delta.abs().toStringAsFixed(1)} kg',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 8),
                if (goal != null)
                  Row(
                    children: [
                      Text('🎯 目标 ${goal!.toStringAsFixed(1)} kg',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 15, color: Colors.white70)),
                    ],
                  )
                else
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: Size.zero,
                      ),
                      onPressed: onEdit,
                      child: const Text('🎯 设定目标'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.metric, required this.series});

  final _Metric metric;
  final List<Measurement> series;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: metric.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Text('${metric.emoji} 再记录几次，${metric.label}趋势就出来了',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final vals = series.map((e) => e.valueOf(metric.key)!).toList();
    final spots = [for (var i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i])];
    final minY = vals.reduce((a, b) => a < b ? a : b) - 1.5;
    final maxY = vals.reduce((a, b) => a > b ? a : b) + 1.5;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: ((maxY - minY) / 3).clamp(0.5, 1e6)),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
            ),
            lineTouchData: const LineTouchData(enabled: true),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: metric.color,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [metric.color.withValues(alpha: 0.28), metric.color.withValues(alpha: 0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All metrics on one chart. Each metric is min-max normalized to 0–1 (量级不同
/// 无法同轴直接比较), so lines show *relative* trend; a legend maps color→metric.
class _CompositeChart extends StatelessWidget {
  const _CompositeChart({required this.items, required this.metrics});

  final List<Measurement> items;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];
    for (final m in metrics) {
      final idx = <int>[];
      final vals = <double>[];
      for (var i = 0; i < items.length; i++) {
        final v = items[i].valueOf(m.key);
        if (v != null) {
          idx.add(i);
          vals.add(v);
        }
      }
      if (vals.length < 2) continue;
      final lo = vals.reduce((a, b) => a < b ? a : b);
      final hi = vals.reduce((a, b) => a > b ? a : b);
      final range = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
      final spots = [for (var k = 0; k < idx.length; k++) FlSpot(idx[k].toDouble(), (vals[k] - lo) / range)];
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: m.color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      ));
    }
    if (bars.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Text('多记录几次，复合趋势就出来了',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: -0.05,
                maxY: 1.05,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: bars,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: metrics.where((m) => items.where((e) => e.valueOf(m.key) != null).length >= 2).map((m) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${m.emoji} ${m.label}', style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text('各指标已归一化，仅看相对走势', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({required this.items, required this.metrics});

  final List<Measurement> items;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final cardW = (MediaQuery.of(context).size.width - AppTheme.pad * 2 - 10) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((m) {
        final vals = items.where((e) => e.valueOf(m.key) != null).toList();
        final latest = vals.last.valueOf(m.key)!;
        double? delta;
        if (vals.length >= 2) delta = latest - vals[vals.length - 2].valueOf(m.key)!;
        return Container(
          width: cardW,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: m.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(m.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(m.label, style: TextStyle(color: m.color, fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  if (delta != null && delta != 0)
                    Text('${delta < 0 ? '↓' : '↑'}${delta.abs().toStringAsFixed(1)}',
                        style: TextStyle(color: m.color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${latest.toStringAsFixed(1)} ${m.unit}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.m, required this.onDelete});

  final Measurement m;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = m.recordedAt;
    final date = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    final bits = <String>[
      if (m.weight != null) '${m.weight!.toStringAsFixed(1)}kg',
      if (m.bodyFat != null) '体脂${m.bodyFat!.toStringAsFixed(1)}%',
      if (m.waist != null) '腰${m.waist!.toStringAsFixed(0)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Text('📈', style: TextStyle(fontSize: 22)),
        title: Text(bits.isEmpty ? '记录' : bits.join('  ·  '), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing: PopupMenuButton<String>(
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('删除'))],
        ),
      ),
    );
  }
}
