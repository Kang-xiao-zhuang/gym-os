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
        loading: () => const ListSkeleton(leading: 44),
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
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await WorkoutRepository.deleteSession(list[i].id);
                    ref.invalidate(sessionsProvider);
                    ref.invalidate(insightsProvider);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('删除失败：$e')));
                  }
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
    final hasPr = s.prCount > 0;
    const gold = Color(0xFFF59E0B);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onOpen,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (hasPr ? gold : const Color(0xFF6366F1)).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(hasPr ? '🏆' : '🏋️', style: const TextStyle(fontSize: 22)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(s.dayTitle?.isNotEmpty == true ? s.dayTitle! : '训练',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (hasPr) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('🏆 破纪录${s.prCount > 1 ? ' ×${s.prCount}' : ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gold)),
              ),
            ],
          ],
        ),
        subtitle: Text([
          fmtDate(s.when),
          '${s.totalSets} 组',
          if (s.totalVolume > 0) '${s.totalVolume.toStringAsFixed(0)} kg',
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
