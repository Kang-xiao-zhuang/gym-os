import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/body_part.dart';
import '../history/session_providers.dart';
import 'rest_timer.dart';
import 'workout_models.dart';
import 'workout_providers.dart';
import 'workout_repository.dart';

/// Marks whether a given training day was already completed *today*, so a
/// reload after finishing doesn't show the workout as still pending.
class DoneTodayStore {
  static String _key(String dayId) {
    final n = DateTime.now();
    return 'done_today_${dayId}_${n.year}-${n.month}-${n.day}';
  }

  static Future<bool> isDone(String dayId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key(dayId)) ?? false;
  }

  static Future<void> setDone(String dayId, bool v) async {
    final p = await SharedPreferences.getInstance();
    if (v) {
      await p.setBool(_key(dayId), true);
    } else {
      await p.remove(_key(dayId));
    }
  }
}

/// Persists in-progress set inputs (weight/reps/done per exercise) for a day+date,
/// so a mid-workout reload doesn't lose what you've entered.
class ProgressStore {
  static String _key(String dayId) {
    final n = DateTime.now();
    return 'progress_${dayId}_${n.year}-${n.month}-${n.day}';
  }

  static Future<Map<String, dynamic>?> load(String dayId) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key(dayId));
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> save(String dayId, Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(dayId), jsonEncode(data));
  }

  static Future<void> clear(String dayId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(dayId));
  }
}

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
  DateTime _start = DateTime.now();
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  /// null = still loading the "done today" flag.
  bool? _doneToday;

  /// Saved in-progress inputs (exId → list of {w,reps,done}); null until loaded.
  Map<String, dynamic>? _saved;

  @override
  void initState() {
    super.initState();
    () async {
      final done = await DoneTodayStore.isDone(widget.dayId);
      final saved = await ProgressStore.load(widget.dayId);
      if (mounted) {
        setState(() {
          _doneToday = done;
          _saved = saved;
        });
      }
    }();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_start));
    });
  }

  void _persist() {
    final map = <String, dynamic>{};
    _rows.forEach((exId, rows) {
      map[exId] = rows
          .map((r) => {'w': r.weight.text, 'reps': r.reps.text, 'done': r.done})
          .toList();
    });
    ProgressStore.save(widget.dayId, map);
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
      final savedRows = _saved?[e.id] as List<dynamic>?;
      if (savedRows != null && savedRows.isNotEmpty) {
        return savedRows.asMap().entries.map((en) {
          final m = en.value as Map<String, dynamic>;
          final row = _SetRow(
            en.key + 1,
            TextEditingController(text: m['w']?.toString() ?? ''),
            TextEditingController(text: m['reps']?.toString() ?? ''),
          );
          row.done = m['done'] == true;
          return row;
        }).toList();
      }
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
    _persist();
  }

  void _removeSet(DayExercise e) {
    final rows = _rowsFor(e);
    if (rows.length <= 1) return;
    final r = rows.removeLast();
    r.weight.dispose();
    r.reps.dispose();
    setState(() {});
    _persist();
  }

  /// Fill every (not-yet-done) set of an exercise with the coached target.
  void _applySuggestion(DayExercise e, double? weight, int? reps) {
    setState(() {
      for (final r in _rowsFor(e)) {
        if (r.done) continue;
        if (weight != null) r.weight.text = _fmtW(weight);
        if (reps != null) r.reps.text = '$reps';
      }
    });
    _persist();
  }

  String get _elapsedText {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Live total volume = every set that has both weight and reps filled in
  /// (whether or not it's checked), so the number responds as you type.
  double _volume(List<DayExercise> items) {
    var v = 0.0;
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        final w = double.tryParse(r.weight.text);
        final reps = int.tryParse(r.reps.text);
        if (w != null && reps != null) v += w * reps;
      }
    }
    return v;
  }

  /// Total reps across every set with a reps value — the meaningful headline
  /// for bodyweight days where volume (weight×reps) is 0.
  int _totalReps(List<DayExercise> items) {
    var n = 0;
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        final reps = int.tryParse(r.reps.text);
        if (reps != null) n += reps;
      }
    }
    return n;
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
    final bestW = <String, double>{};       // exerciseId → heaviest completed weight today
    final bestWReps = <String, int>{};       // reps at that heaviest weight
    final sumReps = <String, int>{};         // total reps this session (for bodyweight PRs)
    for (final e in items) {
      for (final r in _rows[e.id] ?? const <_SetRow>[]) {
        if (!r.done) continue;
        final w = double.tryParse(r.weight.text);
        final reps = int.tryParse(r.reps.text);
        logs.add({
          'exerciseId': e.exerciseId,
          'setNo': r.no,
          'weight': w,
          'reps': reps,
        });
        if (w != null && (bestW[e.exerciseId] == null || w > bestW[e.exerciseId]!)) {
          bestW[e.exerciseId] = w;
          bestWReps[e.exerciseId] = reps ?? 0;
        }
        if (reps != null) {
          sumReps[e.exerciseId] = (sumReps[e.exerciseId] ?? 0) + reps;
        }
      }
    }
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先完成至少一组 💪')));
      return;
    }
    final minutes = _elapsed.inMinutes;
    final vol = _volume(items);
    final totalReps = logs.fold<int>(0, (s, l) => s + ((l['reps'] as int?) ?? 0));

    // Detect personal records BEFORE saving this session, so the PR query
    // reflects history up to *before* today. A heavier top set than the old
    // record (or a first-ever weighted lift) counts as a new PR.
    String fmtW(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final prs = <PrHit>[];
    for (final e in items) {
      try {
        final prev = await WorkoutRepository.personalRecord(e.exerciseId);
        if (e.isBodyweight) {
          // Bodyweight → record is the most TOTAL reps in a single session.
          final todayReps = sumReps[e.exerciseId];
          if (todayReps == null) continue;
          final prevReps = (prev?['bestReps'] as num?)?.toInt();
          if (prevReps == null || todayReps > prevReps) {
            prs.add(PrHit(
              name: e.exerciseName,
              emoji: bodyPartStyle(e.bodyPart ?? '').emoji,
              valueText: '$todayReps 次',
              prevText: prevReps == null ? null : '$prevReps 次',
            ));
          }
        } else {
          // Weighted → record is heaviest top set.
          final w = bestW[e.exerciseId];
          if (w == null) continue;
          final prevMax = (prev?['maxWeight'] as num?)?.toDouble();
          if (prevMax == null || w > prevMax) {
            final reps = bestWReps[e.exerciseId] ?? 0;
            prs.add(PrHit(
              name: e.exerciseName,
              emoji: bodyPartStyle(e.bodyPart ?? '').emoji,
              valueText: reps > 0 ? '${fmtW(w)}kg × $reps' : '${fmtW(w)}kg',
              prevText: prevMax == null ? null : '${fmtW(prevMax)}kg',
            ));
          }
        }
      } catch (_) {/* PR is a nice-to-have; a fetch failure must not block finishing */}
    }

    try {
      await WorkoutRepository.finishSession(
        dayId: widget.dayId,
        startedAt: _start,
        durationMinutes: minutes,
        logs: logs,
      );
      ref.invalidate(sessionsProvider);
      ref.invalidate(insightsProvider);
      for (final e in items) {
        ref.invalidate(lastPerformanceProvider(e.exerciseId));
        ref.invalidate(prProvider(e.exerciseId));
      }
      if (!mounted) return;
      await showCelebration(context, minutes: minutes, sets: logs.length, volume: vol, reps: totalReps, prs: prs);
      await DoneTodayStore.setDone(widget.dayId, true);
      await ProgressStore.clear(widget.dayId);
      if (mounted) {
        setState(() {
          for (final rows in _rows.values) {
            for (final r in rows) {
              r.weight.dispose();
              r.reps.dispose();
            }
          }
          _rows.clear();
          _saved = null;
          _doneToday = true;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记录失败：$e')));
    }
  }

  Future<void> _trainAgain() async {
    await DoneTodayStore.setDone(widget.dayId, false);
    await ProgressStore.clear(widget.dayId);
    if (mounted) {
      setState(() {
        _doneToday = false;
        _saved = null;
        _start = DateTime.now();
        _elapsed = Duration.zero;
      });
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
        if (_doneToday == null) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        if (_doneToday == true) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                const Text('今天已完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('干得漂亮，好好恢复', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _trainAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('再练一次'),
                ),
              ],
            ),
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
                Expanded(
                  child: Text('训练中 $_elapsedText',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text(vol > 0 ? '🏋️ ${vol.toStringAsFixed(0)} kg' : '💪 ${_totalReps(items)} 次',
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
                    HapticFeedback.selectionClick();
                    setState(() => r.done = !r.done);
                    _persist();
                    if (r.done) showRestTimer(context, e.restSeconds ?? 90);
                  },
                  onAdd: () => _addSet(e),
                  onRemove: () => _removeSet(e),
                  onApply: (w, reps) => _applySuggestion(e, w, reps),
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
          onChanged: (_) {
            setState(() {});
            _persist();
          },
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
    required this.onApply,
    required this.numField,
  });

  final DayExercise exercise;
  final List<_SetRow> rows;
  final ValueChanged<_SetRow> onToggle;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final void Function(double? weight, int? reps) onApply;
  final Widget Function(TextEditingController, String) numField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = bodyPartStyle(exercise.bodyPart ?? '');
    final target = [
      if (exercise.targetSets != null && exercise.targetReps != null)
        '目标 ${exercise.targetSets}×${exercise.targetReps}',
    ].join();
    final lastTxt = ref.watch(lastPerformanceProvider(exercise.exerciseId)).value;
    final pr = ref.watch(prProvider(exercise.exerciseId)).value;
    String? prTxt;
    if (pr != null) {
      if (exercise.isBodyweight) {
        if (pr.bestReps != null) prTxt = '${pr.bestReps} 次';
      } else if (pr.maxWeight != null) {
        final w = pr.maxWeight!;
        final wt = w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
        prTxt = pr.maxWeightReps != null ? '${wt}kg×${pr.maxWeightReps}' : '${wt}kg';
      }
    }
    final lastSets = ref.watch(lastSetsProvider(exercise.exerciseId)).value;
    final sug = _overloadSuggestion(exercise, lastSets);
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
            if (lastTxt != null || prTxt != null)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 28),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (lastTxt != null)
                      Text('上次 $lastTxt',
                          style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.w500)),
                    if (prTxt != null)
                      Text('🏆 纪录 $prTxt',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (sug != null && sug.canApply)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 28, right: 2),
                child: Material(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onApply(sug.weight, sug.reps),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(sug.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                          const Text('采用',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w800)),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  ),
                ),
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
                      if (exercise.isBodyweight) ...[
                        numField(r.reps, '次'),
                        const Padding(padding: EdgeInsets.only(left: 6), child: Text('次')),
                      ] else ...[
                        numField(r.weight, 'kg'),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×')),
                        numField(r.reps, '次'),
                      ],
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


/// A personal record broken in a single workout — either heaviest weight
/// (weighted moves) or most reps in a set (bodyweight moves), pre-formatted.
class PrHit {
  PrHit({required this.name, required this.emoji, required this.valueText, this.prevText});
  final String name;
  final String emoji;
  final String valueText; // 今天的成绩，如 "65kg × 5" 或 "15 次"
  final String? prevText; // 旧纪录，如 "92.5kg" 或 "12 次"；null = 首个纪录

  bool get isFirst => prevText == null;
}

/// A progressive-overload coaching hint for the next set of an exercise.
class _Suggestion {
  _Suggestion(this.text, {this.weight, this.reps});
  final String text;
  final double? weight;
  final int? reps;
  bool get canApply => weight != null || reps != null;
}

String _sw(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Suggest today's target from last session's actual performance + the plan target.
/// Weighted: hit all target reps last time → +2.5kg, else repeat and finish the reps.
/// Bodyweight: beat last session's best set by one rep. Null if there's nothing to advise.
_Suggestion? _overloadSuggestion(DayExercise e, List<({double? weight, int? reps})>? last) {
  final hasLast = last != null && last.isNotEmpty;

  if (e.isBodyweight) {
    if (hasLast) {
      final maxReps = last.fold<int>(0, (a, s) => (s.reps ?? 0) > a ? (s.reps ?? 0) : a);
      if (maxReps <= 0) return null;
      return _Suggestion('上次最多一组 $maxReps 次，今天冲 ${maxReps + 1} 次', reps: maxReps + 1);
    }
    if (e.targetReps != null) return _Suggestion('按计划做 ${e.targetReps} 次', reps: e.targetReps);
    return null;
  }

  if (hasLast) {
    final weighted = last.where((s) => s.weight != null).toList();
    if (weighted.isEmpty) return null;
    final topW = weighted.map((s) => s.weight!).reduce((a, b) => b > a ? b : a);
    final repsAtTop = weighted.where((s) => s.weight == topW).map((s) => s.reps ?? 0);
    final minReps = repsAtTop.fold<int>(9999, (a, b) => b < a ? b : a);
    final goal = e.targetReps;
    if (goal != null) {
      if (minReps >= goal) {
        final nw = topW + 2.5;
        return _Suggestion('上次 ${_sw(topW)}kg 做满了，今天试 ${_sw(nw)}kg × $goal', weight: nw, reps: goal);
      }
      return _Suggestion('先把 ${_sw(topW)}kg 的次数做满 $goal 下', weight: topW, reps: goal);
    }
    final r0 = weighted.firstWhere((s) => s.weight == topW).reps;
    return _Suggestion('上次 ${_sw(topW)}kg${r0 != null ? ' × $r0' : ''}，今天争取加量', weight: topW, reps: r0);
  }

  if (e.targetWeight != null) {
    return _Suggestion(
        '按计划 ${_sw(e.targetWeight!)}kg${e.targetReps != null ? ' × ${e.targetReps}' : ''}',
        weight: e.targetWeight, reps: e.targetReps);
  }
  return null;
}

/// Full-screen celebration shown after finishing a workout: confetti + big
/// title + this-session stats, plus a 🏆 callout for any personal records.
Future<void> showCelebration(BuildContext context,
    {required int minutes, required int sets, required double volume, required int reps, List<PrHit> prs = const []}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _CelebrationView(minutes: minutes, sets: sets, volume: volume, reps: reps, prs: prs),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child)),
  );
}

class _CelebrationView extends StatefulWidget {
  const _CelebrationView(
      {required this.minutes, required this.sets, required this.volume, required this.reps, this.prs = const []});
  final int minutes;
  final int sets;
  final double volume;
  final int reps;
  final List<PrHit> prs;

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _confetti.play();
    (widget.prs.isNotEmpty ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  bool get _hasPr => widget.prs.isNotEmpty;

  String get _cheer => _hasPr
      ? '刷新了 ${widget.prs.length} 项纪录，就是这股劲 🔥'
      : widget.volume >= 3000
          ? '今天很猛，就是这个劲头 🔥'
          : widget.sets >= 12
              ? '扎实的一练，干得漂亮 💪'
              : '完成就是胜利，继续保持 👏';

  @override
  Widget build(BuildContext context) {
    final gradient = _hasPr
        ? const [Color(0xFFF59E0B), Color(0xFFEA580C)] // 破纪录 → 金橙
        : const [Color(0xFF6366F1), Color(0xFF8B5CF6)];
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hasPr ? '🏆' : '🎉', style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(_hasPr ? '打破纪录！' : '训练完成！',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('${widget.minutes}', '分钟'),
                      _stat('${widget.sets}', '组'),
                      widget.volume > 0
                          ? _stat(widget.volume.toStringAsFixed(0), 'kg')
                          : _stat('${widget.reps}', '次'),
                    ],
                  ),
                  if (_hasPr) ...[
                    const SizedBox(height: 18),
                    _PrList(prs: widget.prs),
                  ],
                  const SizedBox(height: 18),
                  Text(_cheer, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _hasPr ? const Color(0xFFEA580C) : const Color(0xFF6366F1),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: _hasPr ? 0.08 : 0.05,
            numberOfParticles: _hasPr ? 32 : 20,
            gravity: 0.25,
            shouldLoop: false,
            colors: _hasPr
                ? const [Color(0xFFFFD700), Color(0xFFF59E0B), Color(0xFFFFF3C4), Color(0xFFEA580C), Colors.white]
                : const [
                    Color(0xFF6366F1),
                    Color(0xFFF59E0B),
                    Color(0xFF14B8A6),
                    Color(0xFFEF4444),
                    Color(0xFFEC4899),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}

/// The list of personal records broken this session, shown inside the
/// celebration on a translucent panel.
class _PrList extends StatelessWidget {
  const _PrList({required this.prs});

  final List<PrHit> prs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pr in prs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(pr.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(pr.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(pr.valueText,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      Text(
                        pr.isFirst ? '首个纪录' : '↑ 原 ${pr.prevText}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}