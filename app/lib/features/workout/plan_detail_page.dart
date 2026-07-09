import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import '../exercise/exercise.dart';
import '../exercise/exercise_providers.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

/// Single-screen plan editor: every training day is an expandable section
/// showing its exercises inline, with inline add (multi-select) / delete.
class PlanDetailPage extends ConsumerWidget {
  const PlanDetailPage({super.key, required this.plan});

  final Plan plan;

  Future<void> _addDay(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增训练日'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标题', hintText: '例如：第1天 · 胸'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('添加')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        await WorkoutRepository.addDay(plan.id, title.text.trim());
        ref.invalidate(daysProvider(plan.id));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(daysProvider(plan.id));
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addDay(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('训练日'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (days) {
          if (days.isEmpty) {
            return const Center(child: Text('还没有训练日，点右下角加一个 📆'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(daysProvider(plan.id)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppTheme.pad, AppTheme.pad, AppTheme.pad, 88),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) => _DayTile(planId: plan.id, day: days[i], initiallyExpanded: i == 0),
            ),
          );
        },
      ),
    );
  }
}

class _DayTile extends ConsumerWidget {
  const _DayTile({required this.planId, required this.day, this.initiallyExpanded = false});

  final String planId;
  final Day day;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: false,
          leading: const Text('📆', style: TextStyle(fontSize: 22)),
          title: Text(day.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          children: [_DayBody(planId: planId, day: day)],
        ),
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({required this.planId, required this.day});

  final String planId;
  final Day day;

  Future<void> _addExercises(BuildContext context, WidgetRef ref) async {
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

    final selected = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('选择动作（可多选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView(
                  children: exs.map((e) {
                    final s = bodyPartStyle(e.bodyPart);
                    return CheckboxListTile(
                      value: selected.contains(e.id),
                      onChanged: (v) => setLocal(() => v == true ? selected.add(e.id) : selected.remove(e.id)),
                      secondary: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(e.name),
                      subtitle: Text(e.bodyPart),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('加入 ${selected.isEmpty ? '' : '(${selected.length})'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    try {
      for (final id in selected) {
        await WorkoutRepository.addDayExercise(day.id, exerciseId: id, sets: 4, reps: 10, rest: 90);
      }
      ref.invalidate(dayExercisesProvider(day.id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加入失败：$e')));
    }
  }

  Future<void> _renameDay(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: day.title ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名训练日'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: '例如：第1天 · 胸')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      try {
        await WorkoutRepository.updateDay(day.id, c.text.trim());
        ref.invalidate(daysProvider(planId));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败：$e')));
      }
    }
  }

  Future<void> _deleteDay(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除训练日'),
        content: Text('确定删除「${day.label}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WorkoutRepository.deleteDay(day.id);
      ref.invalidate(daysProvider(planId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayExercisesProvider(day.id));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text('加载失败：$e')),
      data: (items) {
        return Column(
          children: [
            for (final e in items)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Text(bodyPartStyle(e.bodyPart ?? '').emoji, style: const TextStyle(fontSize: 20)),
                title: Text(e.exerciseName),
                subtitle: Text([
                  if (e.volume.isNotEmpty) e.volume,
                  if (e.restSeconds != null) '歇 ${e.restSeconds}s',
                ].join('  ·  ')),
                trailing: IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                  onPressed: () async {
                    await WorkoutRepository.deleteDayExercise(e.id);
                    ref.invalidate(dayExercisesProvider(day.id));
                  },
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('这天还没有动作', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addExercises(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('加动作'),
                ),
                const Spacer(),
                TextButton(onPressed: () => _renameDay(context, ref), child: const Text('重命名')),
                TextButton(
                  onPressed: () => _deleteDay(context, ref),
                  child: Text('删除', style: TextStyle(color: Colors.red.shade300)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
