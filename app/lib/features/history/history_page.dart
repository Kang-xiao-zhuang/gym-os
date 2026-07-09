import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../workout/workout_repository.dart';
import 'session_models.dart';
import 'session_providers.dart';

String fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('训练历史 🏆')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              emoji: '🏆',
              title: '还没有训练记录',
              subtitle: '去「今天」完成一次训练，就会记在这里',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) => _SessionCard(
                s: list[i],
                onOpen: () => context.push('/session-detail', extra: list[i].id),
                onDelete: () async {
                  await WorkoutRepository.deleteSession(list[i].id);
                  ref.invalidate(sessionsProvider);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.s, required this.onOpen, required this.onDelete});

  final WorkoutSessionSummary s;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onOpen,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('🏋️', style: TextStyle(fontSize: 22)),
        ),
        title: Text(s.dayTitle?.isNotEmpty == true ? s.dayTitle! : '训练',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          fmtDate(s.when),
          '${s.exerciseCount} 个动作',
          if (s.durationMinutes != null) '${s.durationMinutes} 分钟',
        ].join('  ·  ')),
        trailing: PopupMenuButton<String>(
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('删除'))],
        ),
      ),
    );
  }
}
