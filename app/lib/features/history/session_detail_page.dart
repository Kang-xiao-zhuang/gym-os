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
                  const SizedBox(height: 8),
                  Text([
                    if (s.finishedAt != null) fmtDate(s.finishedAt!),
                    '${s.exercises.length} 个动作',
                    if (s.durationMinutes != null) '${s.durationMinutes} 分钟',
                  ].join('  ·  '), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('  完成的动作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...s.exercises.map((e) {
              final st = bodyPartStyle(e.bodyPart ?? '');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(st.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: e.bodyPart != null ? Text(e.bodyPart!) : null,
                  trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
