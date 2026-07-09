import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/body_part.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

/// The "today" home block: pick the active plan → pick which day → check off
/// exercises as you train. Completion is local (resets on reload) for now.
class TodaySection extends ConsumerStatefulWidget {
  const TodaySection({super.key});

  @override
  ConsumerState<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends ConsumerState<TodaySection> {
  String? _selectedDayId;
  final Set<String> _done = {};

  Future<void> _pickActive(BuildContext context, List<Plan> plans) async {
    final chosen = await showModalBottomSheet<Plan>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('选择进行中的计划', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ...plans.map((p) => ListTile(
                leading: const Text('📅', style: TextStyle(fontSize: 22)),
                title: Text(p.name),
                trailing: p.isActive == true ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () => Navigator.pop(context, p),
              )),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await WorkoutRepository.activatePlan(chosen.id);
      setState(() {
        _selectedDayId = null;
        _done.clear();
      });
      ref.invalidate(plansProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    return plansAsync.when(
      loading: () => const _Hero(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _Hero(child: Text('加载失败：$e', style: const TextStyle(color: Colors.white))),
      data: (plans) {
        if (plans.isEmpty) {
          return _Hero(
            child: _prompt('还没有训练计划', '创建一个计划，开始你的训练', '去创建', () => context.push('/plans')),
          );
        }
        Plan? active;
        for (final p in plans) {
          if (p.isActive == true) {
            active = p;
            break;
          }
        }
        if (active == null) {
          return _Hero(
            child: _prompt('选择一个进行中的计划', '把某个计划设为进行中，首页就能直接开练', '选择计划', () => _pickActive(context, plans)),
          );
        }
        return _ActivePlanToday(
          plan: active,
          selectedDayId: _selectedDayId,
          done: _done,
          onPickDay: (id) => setState(() {
            _selectedDayId = id;
            _done.clear();
          }),
          onToggle: (id) => setState(() => _done.contains(id) ? _done.remove(id) : _done.add(id)),
          onChangePlan: () => _pickActive(context, plans),
        );
      },
    );
  }

  Widget _prompt(String title, String sub, String btn, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6366F1)),
          onPressed: onTap,
          child: Text(btn),
        ),
      ],
    );
  }
}

/// Active-plan view: day chips + checklist. Watches days/day-exercises providers.
class _ActivePlanToday extends ConsumerWidget {
  const _ActivePlanToday({
    required this.plan,
    required this.selectedDayId,
    required this.done,
    required this.onPickDay,
    required this.onToggle,
    required this.onChangePlan,
  });

  final Plan plan;
  final String? selectedDayId;
  final Set<String> done;
  final ValueChanged<String> onPickDay;
  final ValueChanged<String> onToggle;
  final VoidCallback onChangePlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(daysProvider(plan.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('今天 · ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Expanded(
                    child: Text(plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: onChangePlan,
                    child: const Text('更换', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              daysAsync.maybeWhen(
                data: (days) => days.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('这个计划还没有训练日', style: TextStyle(color: Colors.white70, fontSize: 13)))
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        daysAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('加载失败：$e')),
          data: (days) {
            if (days.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilledButton.tonal(
                  onPressed: () => context.push('/plan-detail', extra: plan),
                  child: const Text('去编排训练日'),
                ),
              );
            }
            final dayId = (selectedDayId != null && days.any((d) => d.id == selectedDayId))
                ? selectedDayId!
                : days.first.id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = days[i];
                      return ChoiceChip(
                        label: Text(d.label),
                        selected: d.id == dayId,
                        onSelected: (_) => onPickDay(d.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _Checklist(dayId: dayId, done: done, onToggle: onToggle),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Checklist extends ConsumerWidget {
  const _Checklist({required this.dayId, required this.done, required this.onToggle});

  final String dayId;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayExercisesProvider(dayId));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('加载失败：$e'),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('这天还没有动作，去计划里加', style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        final doneCount = items.where((e) => done.contains(e.id)).length;
        final allDone = doneCount == items.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(allDone ? '今天练完啦 🎉' : '已完成 $doneCount / ${items.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: items.isEmpty ? 0 : doneCount / items.length,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((e) {
              final isDone = done.contains(e.id);
              final s = bodyPartStyle(e.bodyPart ?? '');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => onToggle(e.id),
                  leading: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    e.exerciseName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text([
                    if (e.volume.isNotEmpty) e.volume,
                    if (e.restSeconds != null) '歇 ${e.restSeconds}s',
                  ].join('  ·  ')),
                  trailing: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isDone ? Colors.green : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Gradient hero container used for the today header.
class _Hero extends StatelessWidget {
  const _Hero({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
