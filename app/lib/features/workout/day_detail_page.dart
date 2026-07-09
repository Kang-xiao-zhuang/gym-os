import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import '../exercise/exercise.dart';
import '../exercise/exercise_providers.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

class DayDetailPage extends ConsumerWidget {
  const DayDetailPage({super.key, required this.day});

  final Day day;

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    List<Exercise> exs;
    try {
      exs = await ref.read(exerciseListProvider.future);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取动作库失败：$e')));
      return;
    }
    if (exs.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('动作库为空，先去添加动作')));
      return;
    }
    if (!context.mounted) return;

    Exercise selected = exs.first;
    final sets = TextEditingController(text: '4');
    final reps = TextEditingController(text: '10');
    final weight = TextEditingController();
    final rest = TextEditingController(text: '90');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('加入动作'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Exercise>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '动作'),
                  items: exs
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text('${bodyPartStyle(e.bodyPart).emoji} ${e.name}')))
                      .toList(),
                  onChanged: (v) => setLocal(() => selected = v ?? selected),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _num(sets, '组数')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(reps, '次数')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _num(weight, '重量kg')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(rest, '组间歇s')),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('加入')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WorkoutRepository.addDayExercise(
        day.id,
        exerciseId: selected.id,
        sets: int.tryParse(sets.text),
        reps: int.tryParse(reps.text),
        weight: double.tryParse(weight.text),
        rest: int.tryParse(rest.text),
      );
      ref.invalidate(dayExercisesProvider(day.id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加入失败：$e')));
    }
  }

  static Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref, DayExercise e) async {
    try {
      await WorkoutRepository.deleteDayExercise(e.id);
      ref.invalidate(dayExercisesProvider(day.id));
    } catch (err) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$err')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayExercisesProvider(day.id));
    return Scaffold(
      appBar: AppBar(title: Text(day.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExercise(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('加动作'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('这天还没有动作，点右下角加入 💪'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dayExercisesProvider(day.id)),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) {
                final e = items[i];
                final s = bodyPartStyle(e.bodyPart ?? '');
                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    title: Text(e.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (e.volume.isNotEmpty) e.volume,
                      if (e.restSeconds != null) '歇 ${e.restSeconds}s',
                    ].join('  ·  ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (_) => _delete(context, ref, e),
                      itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('移除'))],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
