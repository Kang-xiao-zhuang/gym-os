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

/// Small max-weight trend line for the exercise. Hidden until ≥2 sessions.
class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.exerciseId, required this.color});

  final String exerciseId;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(exerciseTrendProvider(exerciseId));
    return trend.maybeWhen(
      data: (weights) {
        if (weights.length < 2) return const SizedBox.shrink();
        final spots = [for (var i = 0; i < weights.length; i++) FlSpot(i.toDouble(), weights[i])];
        final minY = weights.reduce((a, b) => a < b ? a : b) - 2;
        final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text('📈 最大重量趋势', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 140,
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
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
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
              Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
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
