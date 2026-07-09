import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建训练计划'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: '计划名称', hintText: '例如：夏季增肌')),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: const InputDecoration(labelText: '简介（可选）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await WorkoutRepository.createPlan(name.text.trim(), desc.text.trim().isEmpty ? null : desc.text.trim());
        ref.invalidate(plansProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Plan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确定删除「${p.name}」及其所有训练日？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WorkoutRepository.deletePlan(p.id);
      ref.invalidate(plansProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('训练计划 📅')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建计划'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('还没有计划，点右下角新建一个 ✨'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(plansProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.pad),
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
              itemBuilder: (_, i) {
                final p = plans[i];
                return Material(
                  color: const Color(0xFFF97316).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => context.push('/plan-detail', extra: p),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.pad),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                if (p.description != null && p.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(p.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (_) => _delete(context, ref, p),
                            itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('删除'))],
                          ),
                        ],
                      ),
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
