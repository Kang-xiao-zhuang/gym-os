import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'workout_models.dart';

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
