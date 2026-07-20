import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../exercise/exercise.dart';
import '../exercise/exercise_providers.dart';
import '../workout/quick_workout_page.dart';
import 'calendar_models.dart';
import 'calendar_providers.dart';

/// Rolling "下一站" suggestion card (active plan's next day + its exercises).
/// Self-hiding: renders nothing when there's no active plan/day.
class NextUpCard extends ConsumerWidget {
  const NextUpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(nextUpProvider).value;
    if (n == null || n.exercises.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(n.planIcon ?? '🏋️', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('下一站 · ${n.dayTitle}',
                        style: TextStyle(color: scheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      n.lastDoneTitle == null ? n.planName : '${n.planName} · 上次练了「${n.lastDoneTitle}」',
                      style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ex in n.exercises)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ex.targetLabel.isEmpty ? ex.name : '${ex.name} ${ex.targetLabel}',
                    style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: scheme.onPrimary, foregroundColor: scheme.primary),
              onPressed: () => _start(context, ref, n),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始训练'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, NextUp n) async {
    final rootNav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final all = await ref.read(exerciseListProvider.future);
    final ids = n.exercises.map((e) => e.exerciseId).toSet();
    final picked = <Exercise>[for (final e in all) if (ids.contains(e.id)) e];
    if (picked.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('这天的动作在动作库里找不到了')));
      return;
    }
    rootNav.push(MaterialPageRoute(builder: (_) => QuickWorkoutPage(initialExercises: picked)));
  }
}
