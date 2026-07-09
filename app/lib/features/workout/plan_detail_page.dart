import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

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

  Future<void> _deleteDay(BuildContext context, WidgetRef ref, Day d) async {
    try {
      await WorkoutRepository.deleteDay(d.id);
      ref.invalidate(daysProvider(plan.id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(daysProvider(plan.id));
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDay(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('训练日'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (days) {
          if (days.isEmpty) {
            return const Center(child: Text('还没有训练日，加一个吧 📆'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(daysProvider(plan.id)),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) {
                final d = days[i];
                return Card(
                  child: ListTile(
                    leading: const Text('📆', style: TextStyle(fontSize: 24)),
                    title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (_) => _deleteDay(context, ref, d),
                      itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('删除'))],
                    ),
                    onTap: () => context.push('/day-detail', extra: d),
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
