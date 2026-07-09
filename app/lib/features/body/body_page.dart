import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'body_providers.dart';
import 'body_repository.dart';
import 'measurement.dart';

class BodyPage extends ConsumerWidget {
  const BodyPage({super.key});

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final fields = <String, TextEditingController>{
      'weight': TextEditingController(),
      'bodyFat': TextEditingController(),
      'chest': TextEditingController(),
      'waist': TextEditingController(),
      'hip': TextEditingController(),
      'armLeft': TextEditingController(),
      'thighLeft': TextEditingController(),
    };
    const labels = {
      'weight': '体重 kg',
      'bodyFat': '体脂 %',
      'chest': '胸围 cm',
      'waist': '腰围 cm',
      'hip': '臀围 cm',
      'armLeft': '手臂 cm',
      'thighLeft': '大腿 cm',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('记录身体数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: e.value,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: labels[e.key]),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少填一项')));
      return;
    }
    try {
      await BodyRepository.create(body);
      ref.invalidate(measurementsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(measurementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('身体数据 📊')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _record(context, ref),
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
              onAction: () => _record(context, ref),
            );
          }
          final latest = items.last;
          final weighed = items.where((m) => m.weight != null).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(measurementsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pad),
              children: [
                _WeightHeader(weighed: weighed),
                if (weighed.length >= 2) ...[
                  const SizedBox(height: AppTheme.pad),
                  _WeightChart(weighed: weighed),
                ],
                const SizedBox(height: AppTheme.pad),
                _LatestGrid(m: latest),
                const SizedBox(height: 24),
                Text('  历史记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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

class _WeightHeader extends StatelessWidget {
  const _WeightHeader({required this.weighed});

  final List<Measurement> weighed;

  @override
  Widget build(BuildContext context) {
    if (weighed.isEmpty) {
      return const _Card(child: Text('还没有体重记录', style: TextStyle(color: Colors.grey)));
    }
    final latest = weighed.last.weight!;
    double? delta;
    if (weighed.length >= 2) delta = latest - weighed[weighed.length - 2].weight!;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前体重', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${latest.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          if (delta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (delta <= 0 ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${delta <= 0 ? '↓' : '↑'} ${delta.abs().toStringAsFixed(1)} kg',
                style: TextStyle(color: delta <= 0 ? Colors.green : Colors.orange, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.weighed});

  final List<Measurement> weighed;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < weighed.length; i++) FlSpot(i.toDouble(), weighed[i].weight!),
    ];
    final ys = weighed.map((m) => m.weight!).toList();
    final minY = (ys.reduce((a, b) => a < b ? a : b) - 1.5);
    final maxY = (ys.reduce((a, b) => a > b ? a : b) + 1.5);
    const color = Color(0xFF6366F1);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('体重趋势', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: ((maxY - minY) / 3).clamp(0.5, 1000)),
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
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestGrid extends StatelessWidget {
  const _LatestGrid({required this.m});

  final Measurement m;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (m.bodyFat != null) _stat('体脂', '${m.bodyFat!.toStringAsFixed(1)}%'),
      if (m.waist != null) _stat('腰围', '${m.waist!.toStringAsFixed(1)}cm'),
      if (m.chest != null) _stat('胸围', '${m.chest!.toStringAsFixed(1)}cm'),
      if (m.hip != null) _stat('臀围', '${m.hip!.toStringAsFixed(1)}cm'),
      if (m.armLeft != null) _stat('手臂', '${m.armLeft!.toStringAsFixed(1)}cm'),
      if (m.thighLeft != null) _stat('大腿', '${m.thighLeft!.toStringAsFixed(1)}cm'),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: tiles);
  }

  Widget _stat(String label, String value) => Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      );
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
        title: Text(bits.join('  ·  '), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing: PopupMenuButton<String>(
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('删除'))],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.pad),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}
