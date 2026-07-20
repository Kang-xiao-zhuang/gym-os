import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_part.dart';
import '../exercise/exercise.dart';
import '../exercise/exercise_providers.dart';
import '../history/session_providers.dart';
import 'rest_timer.dart';
import 'today_section.dart' show showCelebration, PrHit;
import 'workout_repository.dart';

/// 空手快速记录：不依赖训练计划，直接从动作库挑动作、逐组记录、完成保存。
/// A freestyle (planless) workout: pick exercises from the library on the fly,
/// log sets, and finish — saved as a session with no workoutDayId.
class QuickWorkoutPage extends ConsumerStatefulWidget {
  const QuickWorkoutPage({super.key, this.initialExercises});

  /// Optional exercises to prefill (e.g. "再练一次" from the training calendar).
  final List<Exercise>? initialExercises;

  @override
  ConsumerState<QuickWorkoutPage> createState() => _QuickWorkoutPageState();
}

class _QSet {
  _QSet();
  final TextEditingController weight = TextEditingController();
  final TextEditingController reps = TextEditingController();
  bool done = false;
}

class _QExercise {
  _QExercise(this.exercise) {
    sets.add(_QSet());
  }
  final Exercise exercise;
  final List<_QSet> sets = [];
  bool get isBodyweight => exercise.equipment == '自重';
}

class _QuickWorkoutPageState extends ConsumerState<QuickWorkoutPage> {
  final List<_QExercise> _items = [];
  final DateTime _start = DateTime.now();
  Duration _elapsed = Duration.zero;
  Timer? _tick;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final ex in widget.initialExercises ?? const <Exercise>[]) {
      _items.add(_QExercise(ex));
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_start));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final e in _items) {
      for (final s in e.sets) {
        s.weight.dispose();
        s.reps.dispose();
      }
    }
    super.dispose();
  }

  String get _elapsedText {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  double get _volume {
    var v = 0.0;
    for (final e in _items) {
      for (final s in e.sets) {
        final w = double.tryParse(s.weight.text);
        final r = int.tryParse(s.reps.text);
        if (w != null && r != null) v += w * r;
      }
    }
    return v;
  }

  int get _totalReps {
    var n = 0;
    for (final e in _items) {
      for (final s in e.sets) {
        final r = int.tryParse(s.reps.text);
        if (r != null) n += r;
      }
    }
    return n;
  }

  ({int total, int done}) get _counts {
    var total = 0, done = 0;
    for (final e in _items) {
      for (final s in e.sets) {
        total++;
        if (s.done) done++;
      }
    }
    return (total: total, done: done);
  }

  Future<void> _addExercises() async {
    final list = await ref.read(exerciseListProvider.future);
    if (!mounted) return;
    final present = _items.map((e) => e.exercise.id).toSet();
    final picked = await showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExercisePicker(all: list, alreadyAdded: present),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final ex in picked) {
        if (!_items.any((e) => e.exercise.id == ex.id)) _items.add(_QExercise(ex));
      }
    });
  }

  void _addSet(_QExercise e) {
    setState(() {
      final s = _QSet();
      final last = e.sets.isNotEmpty ? e.sets.last : null;
      if (last != null) {
        s.weight.text = last.weight.text;
        s.reps.text = last.reps.text;
      }
      e.sets.add(s);
    });
  }

  void _removeSet(_QExercise e) {
    if (e.sets.length <= 1) return;
    final s = e.sets.removeLast();
    s.weight.dispose();
    s.reps.dispose();
    setState(() {});
  }

  void _removeExercise(_QExercise e) {
    setState(() {
      for (final s in e.sets) {
        s.weight.dispose();
        s.reps.dispose();
      }
      _items.remove(e);
    });
  }

  Future<void> _finish() async {
    final logs = <Map<String, dynamic>>[];
    final bestW = <String, double>{};
    final bestWReps = <String, int>{};
    final sumReps = <String, int>{};
    for (final e in _items) {
      final id = e.exercise.id;
      var setNo = 0;
      for (final s in e.sets) {
        if (!s.done) continue;
        setNo++;
        final w = double.tryParse(s.weight.text);
        final r = int.tryParse(s.reps.text);
        logs.add({'exerciseId': id, 'setNo': setNo, 'weight': w, 'reps': r});
        if (w != null && (bestW[id] == null || w > bestW[id]!)) {
          bestW[id] = w;
          bestWReps[id] = r ?? 0;
        }
        if (r != null) sumReps[id] = (sumReps[id] ?? 0) + r;
      }
    }
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先完成至少一组 💪')));
      return;
    }
    setState(() => _saving = true);
    final minutes = _elapsed.inMinutes;
    final vol = _volume;
    final reps = _totalReps;

    // Detect PRs BEFORE saving (weighted → heaviest set; bodyweight → session total reps).
    String fmtW(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final prs = <PrHit>[];
    for (final e in _items) {
      final id = e.exercise.id;
      try {
        final prev = await WorkoutRepository.personalRecord(id);
        if (e.isBodyweight) {
          final today = sumReps[id];
          if (today == null) continue;
          final prevReps = (prev?['bestReps'] as num?)?.toInt();
          if (prevReps == null || today > prevReps) {
            prs.add(PrHit(
              name: e.exercise.name,
              emoji: bodyPartStyle(e.exercise.bodyPart).emoji,
              valueText: '$today 次',
              prevText: prevReps == null ? null : '$prevReps 次',
            ));
          }
        } else {
          final w = bestW[id];
          if (w == null) continue;
          final prevMax = (prev?['maxWeight'] as num?)?.toDouble();
          if (prevMax == null || w > prevMax) {
            final r = bestWReps[id] ?? 0;
            prs.add(PrHit(
              name: e.exercise.name,
              emoji: bodyPartStyle(e.exercise.bodyPart).emoji,
              valueText: r > 0 ? '${fmtW(w)}kg × $r' : '${fmtW(w)}kg',
              prevText: prevMax == null ? null : '${fmtW(prevMax)}kg',
            ));
          }
        }
      } catch (_) {/* PR is best-effort */}
    }

    try {
      await WorkoutRepository.finishSession(
        dayId: null,
        startedAt: _start,
        durationMinutes: minutes,
        logs: logs,
      );
      ref.invalidate(sessionsProvider);
      ref.invalidate(insightsProvider);
      if (!mounted) return;
      await showCelebration(context, minutes: minutes, sets: logs.length, volume: vol, reps: reps, prs: prs);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记录失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _counts;
    final canFinish = c.done > 0 && !_saving;
    return Scaffold(
      appBar: AppBar(title: const Text('快速记录 ⚡')),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _items.isEmpty
                ? _empty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: [
                      ..._items.map(_exerciseCard),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _addExercises,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加动作'),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canFinish ? _finish : null,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_saving ? '保存中…' : '完成训练'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final vol = _volume;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('训练中 $_elapsedText',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Text(vol > 0 ? '🏋️ ${vol.toStringAsFixed(0)} kg' : '💪 $_totalReps 次',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('空手练一练', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('不用建计划，直接挑动作开练',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _addExercises,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加动作'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(_QExercise e) {
    final s = bodyPartStyle(e.exercise.bodyPart);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.exercise.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: '组间休息',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.timer_outlined, size: 19, color: Colors.grey.shade500),
                  onPressed: () => showRestTimer(context, 90),
                ),
                IconButton(
                  tooltip: '移除动作',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 19, color: Colors.grey.shade400),
                  onPressed: () => _removeExercise(e),
                ),
              ],
            ),
            ...e.sets.asMap().entries.map((en) {
              final i = en.key;
              final set = en.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text('第${i + 1}组', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ),
                    if (e.isBodyweight) ...[
                      _numField(set.reps, '次'),
                      const Padding(padding: EdgeInsets.only(left: 6), child: Text('次')),
                    ] else ...[
                      _numField(set.weight, 'kg'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×')),
                      _numField(set.reps, '次'),
                    ],
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        set.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: set.done ? Colors.green : Colors.grey.shade400,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => set.done = !set.done);
                        if (set.done) showRestTimer(context, 90);
                      },
                    ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addSet(e),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('加一组'),
                ),
                if (e.sets.length > 1)
                  TextButton.icon(
                    onPressed: () => _removeSet(e),
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

  Widget _numField(TextEditingController controller, String hint) => SizedBox(
        width: 56,
        child: TextField(
          controller: controller,
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

/// Bottom-sheet exercise picker: search + tap to (de)select, confirm to add all.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.all, required this.alreadyAdded});

  final List<Exercise> all;
  final Set<String> alreadyAdded;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _picked = <String>{};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final list = widget.all.where((e) {
      if (q.isEmpty) return true;
      return e.name.contains(q) || e.bodyPart.contains(q) || (e.equipment?.contains(q) ?? false);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: '搜索动作 / 部位 / 器械',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(q.isEmpty ? '暂无动作' : '没有找到「$q」',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final e = list[i];
                  final added = widget.alreadyAdded.contains(e.id);
                  final sel = _picked.contains(e.id);
                  final st = bodyPartStyle(e.bodyPart);
                  return ListTile(
                    leading: Text(st.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(e.name),
                    subtitle: Text([e.bodyPart, if (e.equipment != null) e.equipment!].join(' · '),
                        style: const TextStyle(fontSize: 12)),
                    trailing: added
                        ? Text('已在列表', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                        : Icon(sel ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            color: sel ? Colors.green : Colors.grey.shade400),
                    onTap: added
                        ? null
                        : () => setState(() => sel ? _picked.remove(e.id) : _picked.add(e.id)),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context, widget.all.where((e) => _picked.contains(e.id)).toList()),
                    child: Text(_picked.isEmpty ? '选择动作' : '添加 ${_picked.length} 个动作'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
