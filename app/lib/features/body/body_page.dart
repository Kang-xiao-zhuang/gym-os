import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'body_providers.dart';
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
          if (!withData.any((m) => m.key == _metricKey) && withData.isNotEmpty) {
            _metricKey = withData.first.key;
          }
          final selected = _metrics.firstWhere((m) => m.key == _metricKey);
          final series = items.where((e) => e.valueOf(_metricKey) != null).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(measurementsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pad),
              children: [
                _Hero(metric: _metrics.first, series: items.where((e) => e.weight != null).toList()),
                const SizedBox(height: 20),
                Text('  趋势', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: withData.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final m = withData[i];
                      final sel = m.key == _metricKey;
                      return ChoiceChip(
                        label: Text('${m.emoji} ${m.label}'),
                        selected: sel,
                        selectedColor: m.color.withValues(alpha: 0.18),
                        onSelected: (_) => setState(() => _metricKey = m.key),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _TrendChart(metric: selected, series: series),
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

/// Gradient headline card for weight (with latest value + delta).
class _Hero extends StatelessWidget {
  const _Hero({required this.metric, required this.series});

  final _Metric metric;
  final List<Measurement> series;

  @override
  Widget build(BuildContext context) {
    final latest = series.isNotEmpty ? series.last.weight : null;
    double? delta;
    if (series.length >= 2) delta = series.last.weight! - series[series.length - 2].weight!;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前体重', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(latest != null ? '${latest.toStringAsFixed(1)} kg' : '— kg',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                if (delta != null) ...[
                  const SizedBox(height: 8),
                  Text('${delta <= 0 ? '↓ 掉了' : '↑ 涨了'} ${delta.abs().toStringAsFixed(1)} kg（比上次）',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const Text('⚖️', style: TextStyle(fontSize: 44)),
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
