import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/body_part.dart';
import '../history/session_providers.dart';
import 'rest_timer.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

/// The "today" home block: pick the active plan → pick which day → log sets.
class TodaySection extends ConsumerStatefulWidget {
  const TodaySection({super.key});

  @override
  ConsumerState<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends ConsumerState<TodaySection> {
  String? _selectedDayId;

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
                leading: Text(p.displayIcon, style: const TextStyle(fontSize: 22)),
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
      setState(() => _selectedDayId = null);
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
          return _Hero(child: _prompt('还没有训练计划', '创建一个计划，开始你的训练', '去创建', () => context.push('/plans')));
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
            child: _prompt('选择一个进行中的计划', '把某个计划设为进行中，首页就能直接开练', '选择计划',
                () => _pickActive(context, plans)),
          );
        }
        return _ActivePlanToday(
          plan: active,
          selectedDayId: _selectedDayId,
          onPickDay: (id) => setState(() => _selectedDayId = id),
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

class _ActivePlanToday extends ConsumerWidget {
  const _ActivePlanToday({
    required this.plan,
    required this.selectedDayId,
    required this.onPickDay,
    required this.onChangePlan,
  });

  final Plan plan;
  final String? selectedDayId;
  final ValueChanged<String> onPickDay;
  final VoidCallback onChangePlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(daysProvider(plan.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(
          child: Row(
            children: [
              Text(plan.displayIcon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              TextButton(onPressed: onChangePlan, child: const Text('更换', style: TextStyle(color: Colors.white))),
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
                _SetLogger(key: ValueKey(dayId), dayId: dayId),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One editable set: weight × reps + done flag.
class _SetRow {
  _SetRow(this.no, this.weight, this.reps);
  final int no;
  final TextEditingController weight;
  final TextEditingController reps;
  bool done = false;
}

/// Per-set workout logger for one day. Sets are in-memory for the session and
/// saved to the backend on "完成训练".
class _SetLogger extends ConsumerStatefulWidget {
  const _SetLogger({super.key, required this.dayId});

  final String dayId;

  @override
  ConsumerState<_SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends ConsumerState<_SetLogger> {
  final Map<String, List<_SetRow>> _rows = {};
  final DateTime _start = DateTime.now();
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_start));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final rows in _rows.values) {
      for (final r in rows) {
        r.weight.dispose();
        r.reps.dispose();
      }
    }
    super.dispose();
  }

  static String _fmtW(double? w) => w == null ? '' : (w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1));

  List<_SetRow> _rowsFor(DayExercise e) {
    return _rows.putIfAbsent(e.id, () {
      final n = (e.targetSets ?? 1).clamp(1, 12);
      return List.generate(
        n,
        (i) => _SetRow(i + 1, TextEditingController(text: _fmtW(e.targetWeight)),
            TextEditingController(text: e.targetReps?.toString() ?? '')),
      );
    });
  }

  void _addSet(DayExercise e) {
    final rows = _rowsFor(e);
    final last = rows.isNotEmpty ? rows.last : null;
    setState(() => rows.add(_SetRow(
          rows.length + 1,
          TextEditingController(text: last?.weight.text ?? _fmtW(e.targetWeight)),
          TextEditingController(text: last?.reps.text ?? (e.targetReps?.toString() ?? '')),
        )));
  }

  void _removeSet(DayExercise e) {
    final rows = _rowsFor(e);
    if (rows.length <= 1) return;
    final r = rows.removeLast();
    r.weight.dispose();
    r.reps.dispose();
    setState(() {});
  }

  String get _elapsedText {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  double _volume(List<DayExercise> items) {
    var v = 0.0;
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        if (!r.done) continue;
        final w = double.tryParse(r.weight.text);
        final reps = int.tryParse(r.reps.text);
        if (w != null && reps != null) v += w * reps;
      }
    }
    return v;
  }

  ({int total, int done}) _counts(List<DayExercise> items) {
    var total = 0, done = 0;
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        total++;
        if (r.done) done++;
      }
    }
    return (total: total, done: done);
  }

  Future<void> _finish(List<DayExercise> items) async {
    final logs = <Map<String, dynamic>>[];
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        if (!r.done) continue;
        logs.add({
          'exerciseId': e.exerciseId,
          'setNo': r.no,
          'weight': double.tryParse(r.weight.text),
          'reps': int.tryParse(r.reps.text),
        });
      }
    }
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先完成至少一组 💪')));
      return;
    }
    final minutes = _elapsed.inMinutes;
    final vol = _volume(items);
    try {
      await WorkoutRepository.finishSession(
        dayId: widget.dayId,
        startedAt: _start,
        durationMinutes: minutes,
        logs: logs,
      );
      ref.invalidate(sessionsProvider);
      for (final e in items) {
        ref.invalidate(lastPerformanceProvider(e.exerciseId));
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('训练完成 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⏱ 用时 $minutes 分钟'),
              const SizedBox(height: 6),
              Text('✅ 完成 ${logs.length} 组'),
              const SizedBox(height: 6),
              Text('🏋️ 总容量 ${vol.toStringAsFixed(0)} kg'),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('好的'))],
        ),
      );
      if (mounted) {
        setState(() {
          for (final rows in _rows.values) {
            for (final r in rows) {
              r.weight.dispose();
              r.reps.dispose();
            }
          }
          _rows.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记录失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dayExercisesProvider(widget.dayId));
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
        for (final e in items) {
          _rowsFor(e);
        }
        final c = _counts(items);
        final vol = _volume(items);
        final allDone = c.total > 0 && c.done == c.total;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('训练中 $_elapsedText',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('🏋️ ${vol.toStringAsFixed(0)} kg',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: Text(
                    allDone ? '全部完成 🎉' : '已完成 ${c.done} / ${c.total} 组',
                    key: ValueKey(allDone),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: allDone ? Colors.green : null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: c.total == 0 ? 0 : c.done / c.total),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        color: allDone ? Colors.green : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((e) => _ExerciseSets(
                  exercise: e,
                  rows: _rowsFor(e),
                  onToggle: (r) {
                    setState(() => r.done = !r.done);
                    if (r.done) showRestTimer(context, e.restSeconds ?? 90);
                  },
                  onAdd: () => _addSet(e),
                  onRemove: () => _removeSet(e),
                  numField: _numField,
                )),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _finish(items),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('完成训练'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _numField(TextEditingController c, String hint) => SizedBox(
        width: 56,
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          ),
        ),
      );
}

class _ExerciseSets extends ConsumerWidget {
  const _ExerciseSets({
    required this.exercise,
    required this.rows,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.numField,
  });

  final DayExercise exercise;
  final List<_SetRow> rows;
  final ValueChanged<_SetRow> onToggle;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final Widget Function(TextEditingController, String) numField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = bodyPartStyle(exercise.bodyPart ?? '');
    final target = [
      if (exercise.targetSets != null && exercise.targetReps != null)
        '目标 ${exercise.targetSets}×${exercise.targetReps}',
    ].join();
    final last = ref.watch(lastPerformanceProvider(exercise.exerciseId));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(exercise.exerciseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (target.isNotEmpty)
                  Text(target, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                IconButton(
                  tooltip: '组间休息',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: Icon(Icons.timer_outlined, size: 19, color: Colors.grey.shade500),
                  onPressed: () => showRestTimer(context, exercise.restSeconds ?? 90),
                ),
              ],
            ),
            last.maybeWhen(
              data: (txt) => txt == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 2, left: 28),
                      child: Text('上次 $txt',
                          style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.w500)),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text('第${r.no}组', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      numField(r.weight, 'kg'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×')),
                      numField(r.reps, '次'),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          r.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: r.done ? Colors.green : Colors.grey.shade400,
                        ),
                        onPressed: () => onToggle(r),
                      ),
                    ],
                  ),
                )),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('加一组'),
                ),
                if (rows.length > 1)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('减一组'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
