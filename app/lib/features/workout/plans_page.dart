import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final desc = TextEditingController();
    var icon = '📅';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('新建训练计划'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanIconPicker(selected: icon, onPick: (e) => setLocal(() => icon = e)),
              const SizedBox(height: 12),
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
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await WorkoutRepository.createPlan(
            name.text.trim(), desc.text.trim().isEmpty ? null : desc.text.trim(),
            icon: icon);
        ref.invalidate(plansProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Plan p) async {
    final name = TextEditingController(text: p.name);
    final desc = TextEditingController(text: p.description ?? '');
    var icon = p.displayIcon;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('编辑计划'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanIconPicker(selected: icon, onPick: (e) => setLocal(() => icon = e)),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: '计划名称')),
              const SizedBox(height: 12),
              TextField(controller: desc, decoration: const InputDecoration(labelText: '简介（可选）')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await WorkoutRepository.updatePlan(p.id,
            name: name.text.trim(), description: desc.text.trim().isEmpty ? null : desc.text.trim(),
            icon: icon);
        ref.invalidate(plansProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
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
        heroTag: null,
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建计划'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyView(emoji: '😵', title: '加载失败', subtitle: '$e'),
        data: (plans) {
          if (plans.isEmpty) {
            return EmptyView(
              emoji: '📅',
              title: '还没有训练计划',
              subtitle: '点右下角新建一个，开始编排',
              actionLabel: '新建计划',
              onAction: () => _createDialog(context, ref),
            );
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
                          Text(p.displayIcon, style: const TextStyle(fontSize: 28)),
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
                            onSelected: (v) => v == 'rename' ? _rename(context, ref, p) : _delete(context, ref, p),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('编辑')),
                              PopupMenuItem(value: 'del', child: Text('删除')),
                            ],
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

/// Horizontal emoji picker for a plan's icon.
class _PlanIconPicker extends StatelessWidget {
  const _PlanIconPicker({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kPlanIcons.map((e) {
        final sel = e == selected;
        return GestureDetector(
          onTap: () => onPick(e),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? scheme.primary.withValues(alpha: 0.18) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: sel ? Border.all(color: scheme.primary, width: 2) : null,
            ),
            child: Text(e, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }
}
