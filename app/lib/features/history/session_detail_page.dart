import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'history_page.dart' show fmtDate;
import 'session_providers.dart';

class SessionDetailPage extends ConsumerWidget {
  const SessionDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('训练详情')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppTheme.pad),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.dayTitle?.isNotEmpty == true ? s.dayTitle! : '训练',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  if (s.finishedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(fmtDate(s.finishedAt!), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _stat('${s.totalSets}', '组'),
                      _stat(s.totalVolume.toStringAsFixed(0), 'kg 容量'),
                      _stat('${s.durationMinutes ?? 0}', '分钟'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...s.exercises.map((e) {
              final st = bodyPartStyle(e.bodyPart ?? '');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(st.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text('${e.sets.length} 组', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...e.sets.map((set) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text('第${set.setNo ?? '-'}组',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ),
                                Expanded(
                                  child: Text(set.label,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
}
