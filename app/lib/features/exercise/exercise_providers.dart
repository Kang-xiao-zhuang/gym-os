import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../workout/workout_repository.dart';
import 'exercise.dart';

/// Fetches the exercise library from the backend. Auto-disposed so it re-fetches
/// each time the list page is entered; call `ref.invalidate` to force a refresh.
final exerciseListProvider = FutureProvider.autoDispose<List<Exercise>>((ref) async {
  final data = await ApiClient.get('/api/exercises') as List<dynamic>;
  return data
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});

/// Personal record of an exercise; null if never lifted with weight.
final prProvider = FutureProvider.autoDispose.family<PrInfo?, String>((ref, exerciseId) async {
  final data = await WorkoutRepository.personalRecord(exerciseId);
  if (data == null) return null;
  return PrInfo.fromJson(data);
});

class PrInfo {
  PrInfo({this.maxWeight, this.maxWeightReps, this.bestSetVolume});
  final double? maxWeight;
  final int? maxWeightReps;
  final double? bestSetVolume;

  factory PrInfo.fromJson(Map<String, dynamic> j) => PrInfo(
        maxWeight: (j['maxWeight'] as num?)?.toDouble(),
        maxWeightReps: (j['maxWeightReps'] as num?)?.toInt(),
        bestSetVolume: (j['bestSetVolume'] as num?)?.toDouble(),
      );

  static String _n(num? v) => v == null ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));
  String get maxWeightLabel =>
      maxWeight == null ? '—' : '${_n(maxWeight)} kg${maxWeightReps != null ? ' × $maxWeightReps' : ''}';
  String get bestVolumeLabel => bestSetVolume == null ? '—' : '${_n(bestSetVolume)} kg';
}
