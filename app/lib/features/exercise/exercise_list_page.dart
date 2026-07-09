import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
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
        onPressed: () => context.push('/exercise-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(exerciseListProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('还没有动作，去加一个吧 ✨'));
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip('${s.emoji} ${exercise.bodyPart}', s.color),
                        if (exercise.equipment != null) ...[
                          const SizedBox(width: 6),
                          _Chip(exercise.equipment!, Colors.blueGrey),
                        ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😵', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('加载失败：$message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
