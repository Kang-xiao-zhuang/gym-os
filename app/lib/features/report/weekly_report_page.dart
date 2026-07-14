import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html; // web-only build; used to download the generated PNG

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/session_models.dart';
import '../history/session_providers.dart';

/// This-week (or any-week) training summary rendered as a shareable card that
/// can be saved as a PNG. All figures are derived from the session list.
class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeekStats {
  _WeekStats(this.days, this.sessions, this.sets, this.volumeKg, this.prs);
  final int days;
  final int sessions;
  final int sets;
  final double volumeKg;
  final int prs;

  bool get empty => sessions == 0;
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  final _cardKey = GlobalKey();
  int _weekOffset = 0; // 0 = this week, -1 = last week …
  bool _saving = false;

  DateTime get _weekStart {
    final n = DateTime.now();
    final monday = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  _WeekStats _statsFor(List<WorkoutSessionSummary> sessions, DateTime start) {
    final end = start.add(const Duration(days: 7));
    final inWeek = sessions.where((s) => !s.when.isBefore(start) && s.when.isBefore(end));
    final days = <DateTime>{};
    var sets = 0, prs = 0;
    var vol = 0.0;
    for (final s in inWeek) {
      days.add(DateTime(s.when.year, s.when.month, s.when.day));
      sets += s.totalSets;
      vol += s.totalVolume;
      prs += s.prCount;
    }
    return _WeekStats(days.length, inWeek.length, sets, vol, prs);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('卡片未就绪');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('导出失败');
      final bytes = data.buffer.asUint8List();
      final d = _weekStart;
      final name = 'gymos-周报-${d.year}${_two(d.month)}${_two(d.day)}.png';
      _downloadPng(bytes, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存周报图片 📤')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _downloadPng(Uint8List bytes, String filename) {
    final blob = html.Blob(<Object>[bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('训练周报 📤')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (sessions) {
          final start = _weekStart;
          final stats = _statsFor(sessions, start);
          return ListView(
            padding: const EdgeInsets.all(AppTheme.pad),
            children: [
              _weekSwitcher(start),
              const SizedBox(height: 16),
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _ShareCard(start: start, stats: stats),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                  label: Text(_saving ? '生成中…' : '保存周报图片'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('图片会保存到浏览器下载文件夹',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _weekSwitcher(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final label = _weekOffset == 0
        ? '本周'
        : _weekOffset == -1
            ? '上周'
            : '${-_weekOffset} 周前';
    return Row(
      children: [
        IconButton(onPressed: () => setState(() => _weekOffset--), icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Center(
            child: Text('$label · ${start.month}/${start.day} – ${end.month}/${end.day}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        IconButton(
          onPressed: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.start, required this.stats});

  final DateTime start;
  final _WeekStats stats;

  String get _volumeText {
    if (stats.volumeKg >= 1000) return '${(stats.volumeKg / 1000).toStringAsFixed(1)} 吨';
    return '${stats.volumeKg.toStringAsFixed(0)} kg';
  }

  String get _cheer {
    final d = stats.days;
    if (stats.empty) return '这周还没开练，下周动起来 💪';
    if (d >= 7) return '全勤达成，你太强了 🏆';
    if (d >= 5) return '这一周很拼，为你鼓掌 🔥';
    if (d >= 3) return '稳定输出，保持住 💪';
    return '开了个好头，继续加油 👏';
  }

  @override
  Widget build(BuildContext context) {
    final end = start.add(const Duration(days: 6));
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🏋️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Text('GymOS 训练周报',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${start.month}/${start.day}–${end.month}/${end.day}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 8),
              Text('${stats.days}',
                  style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('天打卡', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _stat('训练', '${stats.sessions}', '次'),
              _divider(),
              _stat('组数', '${stats.sets}', '组'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('总容量', _volumeText, ''),
              _divider(),
              _stat('破纪录', '${stats.prs}', '项'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_cheer,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('Plan · Train · Record · Improve',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String unit) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 3),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: value,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                if (unit.isNotEmpty)
                  TextSpan(text: ' $unit', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.2));
}
