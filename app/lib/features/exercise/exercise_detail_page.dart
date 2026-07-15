import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import 'exercise.dart';
import 'exercise_providers.dart';
import 'exercise_repository.dart';

class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  late String? _imageUrl = widget.exercise.imageUrl;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final e = widget.exercise;
      final url = await ExerciseRepository.uploadImage(
        e.id,
        bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      await ExerciseRepository.update(e.id, {
        'name': e.name,
        'bodyPart': e.bodyPart,
        'equipment': e.equipment,
        'difficulty': e.difficulty,
        'description': e.description,
        'imageUrl': url,
        'videoUrl': e.videoUrl,
      });
      ref.invalidate(exerciseListProvider);
      if (mounted) setState(() => _imageUrl = url);
      _toast('图片已更新 ✅');
    } catch (e) {
      _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final s = bodyPartStyle(e.bodyPart);
    return Scaffold(
      appBar: AppBar(
        title: Text(e.name),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/exercise-form', extra: e),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pad),
        children: [
          _ImageHeader(url: _imageUrl, style: s, uploading: _uploading),
          const SizedBox(height: AppTheme.gap),
          FilledButton.tonalIcon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_imageUrl == null ? '上传示范图' : '更换图片'),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip('${s.emoji} ${e.bodyPart}', s.color),
              if (e.equipment != null) _Chip('🏋️ ${e.equipment}', Colors.blueGrey),
              if ((e.difficulty ?? 0) > 0) _Chip('难度 ${difficultyFlames(e.difficulty)}', Colors.deepOrange),
            ],
          ),
          const SizedBox(height: 20),
          _PrCard(exerciseId: e.id),
          _TrendCard(exerciseId: e.id, color: s.color),
          if (e.description != null) ...[
            const SizedBox(height: 20),
            Text('📝 动作说明',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(e.description!, style: const TextStyle(height: 1.6, fontSize: 14.5)),
          ],
        ],
      ),
    );
  }
}

/// Personal-record card: max weight + best single-set volume. Hidden until the
/// exercise has been logged with weight at least once.
class _PrCard extends ConsumerWidget {
  const _PrCard({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pr = ref.watch(prProvider(exerciseId));
    return pr.maybeWhen(
      data: (info) {
        if (info == null || info.maxWeight == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🏆 个人记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _prStat('最大重量', info.maxWeightLabel),
                  _prStat('最佳单组容量', info.bestVolumeLabel),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _prStat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

enum _Metric { est1rm, maxWeight, volume }

/// Multi-metric strength curve: estimated 1RM / top weight / volume over sessions,
/// with a headline gain vs the first record. Hidden until ≥2 sessions exist.
class _TrendCard extends ConsumerStatefulWidget {
  const _TrendCard({required this.exerciseId, required this.color});

  final String exerciseId;
  final Color color;

  @override
  ConsumerState<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<_TrendCard> {
  _Metric? _picked;

  static const Map<_Metric, ({String label, String unit})> _meta = {
    _Metric.est1rm: (label: '估算1RM', unit: 'kg'),
    _Metric.maxWeight: (label: '最大重量', unit: 'kg'),
    _Metric.volume: (label: '训练容量', unit: 'kg'),
  };

  double? _value(_Metric m, TrendPoint p) => switch (m) {
        _Metric.est1rm => p.est1rm,
        _Metric.maxWeight => p.maxWeight,
        _Metric.volume => p.volume,
      };

  List<(DateTime?, double)> _series(_Metric m, List<TrendPoint> pts) {
    final out = <(DateTime?, double)>[];
    for (final p in pts) {
      final v = _value(m, p);
      if (v != null && (m != _Metric.volume || v > 0)) out.add((p.date, v));
    }
    return out;
  }

  static String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final trend = ref.watch(exerciseTrendProvider(widget.exerciseId));
    return trend.maybeWhen(
      data: (points) {
        final available = _Metric.values.where((m) => _series(m, points).length >= 2).toList();
        if (available.isEmpty) return const SizedBox.shrink();
        final metric = (_picked != null && available.contains(_picked)) ? _picked! : available.first;
        final series = _series(metric, points);
        final unit = _meta[metric]!.unit;

        final values = series.map((e) => e.$2).toList();
        final first = values.first, last = values.last;
        final delta = last - first;
        final minV = values.reduce((a, b) => a < b ? a : b);
        final maxV = values.reduce((a, b) => a > b ? a : b);
        final pad = ((maxV - minV) * 0.15).clamp(1.0, 1e9);
        final spots = [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];
        final labelStep = (series.length / 4).ceil().clamp(1, 9999);

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📈 力量曲线', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (available.length > 1)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_Metric>(
                      segments: [
                        for (final m in available)
                          ButtonSegment(value: m, label: Text(_meta[m]!.label, style: const TextStyle(fontSize: 12))),
                      ],
                      selected: {metric},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onSelectionChanged: (s) => setState(() => _picked = s.first),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${_fmt(last)} $unit',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text(
                      delta >= 0 ? '较首次 +${_fmt(delta)}' : '较首次 ${_fmt(delta)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: delta >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      minY: minV - pad,
                      maxY: maxV + pad,
                      gridData: FlGridData(
                          show: true, drawVerticalLine: false, horizontalInterval: ((maxV - minV + 2 * pad) / 3).clamp(0.5, 1e9)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (x, meta) {
                              final i = x.toInt();
                              if (i < 0 || i >= series.length) return const SizedBox.shrink();
                              if (i % labelStep != 0 && i != series.length - 1) return const SizedBox.shrink();
                              final d = series[i].$1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(d == null ? '' : '${d.month}/${d.day}',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                              );
                            },
                          ),
                        ),
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
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({this.url, required this.style, required this.uploading});

  final String? url;
  final BodyPartStyle style;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [style.color.withValues(alpha: 0.18), style.color.withValues(alpha: 0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url!.isNotEmpty)
              Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: 900,
                frameBuilder: (_, child, frame, wasSync) => wasSync
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                errorBuilder: (_, _, _) => _placeholder(),
              )
            else
              _placeholder(),
            if (uploading)
              Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Center(child: Text(style.emoji, style: const TextStyle(fontSize: 72)));
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)),
      child: Text(text, style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w600)),
    );
  }
}
