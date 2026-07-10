import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'workout_models.dart';
import 'workout_repository.dart';

final plansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final data = await ApiClient.get('/api/plans') as List<dynamic>;
  return data.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
});

final daysProvider = FutureProvider.autoDispose.family<List<Day>, String>((ref, planId) async {
  final data = await ApiClient.get('/api/plans/$planId/days') as List<dynamic>;
  return data.map((e) => Day.fromJson(e as Map<String, dynamic>)).toList();
});

final dayExercisesProvider = FutureProvider.autoDispose.family<List<DayExercise>, String>((ref, dayId) async {
  final data = await ApiClient.get('/api/days/$dayId/exercises') as List<dynamic>;
  return data.map((e) => DayExercise.fromJson(e as Map<String, dynamic>)).toList();
});

/// "上次成绩" for an exercise, formatted as e.g. "60×10 · 62.5×8"; null if never done.
final lastPerformanceProvider = FutureProvider.autoDispose.family<String?, String>((ref, exerciseId) async {
  final data = await WorkoutRepository.lastPerformance(exerciseId);
  if (data == null) return null;
  final sets = (data['sets'] as List<dynamic>? ?? []);
  if (sets.isEmpty) return null;
  String fmt(num? w) => w == null ? '' : (w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1));
  return sets.map((s) {
    final m = s as Map<String, dynamic>;
    final w = m['weight'] as num?;
    final reps = m['reps'] as num?;
    if (w != null && reps != null) return '${fmt(w)}×$reps';
    if (reps != null) return '×$reps';
    return '';
  }).where((s) => s.isNotEmpty).join(' · ');
});
