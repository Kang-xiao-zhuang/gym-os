import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'exercise.dart';
import 'exercise_providers.dart';

class ExerciseListPage extends ConsumerWidget {
  const ExerciseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库 💪'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(exerciseListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/exercise-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(
          emoji: '😵',
          title: '加载失败',
          subtitle: '$e',
          actionLabel: '重试',
          onAction: () => ref.invalidate(exerciseListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              emoji: '💪',
              title: '还没有动作',
              subtitle: '点右下角新增第一个动作',
              actionLabel: '新增动作',
              onAction: () => context.push('/exercise-form'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(exerciseListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('共 ${list.length} 个动作',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  );
                }
                final e = list[i - 1];
                return _ExerciseCard(exercise: e, onTap: () => context.push('/exercise-detail', extra: e));
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = bodyPartStyle(exercise.bodyPart);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.all(AppTheme.gap),
          child: Row(
            children: [
              _Thumb(url: exercise.imageUrl, style: s),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip('${s.emoji} ${exercise.bodyPart}', s.color),
                        if (exercise.equipment != null) _Chip(exercise.equipment!, Colors.blueGrey),
                      ],
                    ),
                    if ((exercise.difficulty ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Text(difficultyFlames(exercise.difficulty), style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url, required this.style});

  final String? url;
  final BodyPartStyle style;

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    Widget placeholder() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(style.emoji, style: const TextStyle(fontSize: 30)),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: (url == null || url!.isEmpty)
          ? placeholder()
          : Image.network(url!, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder()),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

