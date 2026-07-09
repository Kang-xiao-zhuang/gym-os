import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        title: const Text('动作库'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(exerciseListProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(exerciseListProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('动作库还是空的'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(exerciseListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) => _ExerciseCard(
                exercise: list[i],
                onTap: () => context.push('/exercise-detail', extra: list[i]),
              ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gap),
          child: Row(
            children: [
              _Thumb(url: exercise.imageUrl),
              const SizedBox(width: AppTheme.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(exercise.bodyPart, scheme.primary),
                        if (exercise.equipment != null) _Tag(exercise.equipment!, scheme.tertiary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Difficulty(level: exercise.difficulty ?? 0),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 56.0;
    Widget placeholder() => Container(
          width: size,
          height: size,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Icon(Icons.fitness_center, color: scheme.primary.withValues(alpha: 0.6)),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: (url == null || url!.isEmpty)
          ? placeholder()
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _Difficulty extends StatelessWidget {
  const _Difficulty({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.circle,
          size: 7,
          color: i < level ? Colors.orange : Colors.grey.shade300,
        ),
      ),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
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
