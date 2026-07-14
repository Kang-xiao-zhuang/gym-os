import '../../core/api_client.dart';

/// Backend calls for the training-plan module.
class WorkoutRepository {
  static Future<void> createPlan(String name, String? description, {String? icon}) =>
      ApiClient.post('/api/plans', {'name': name, 'description': description, 'icon': icon});

  static Future<void> deletePlan(String planId) => ApiClient.delete('/api/plans/$planId');

  static Future<void> activatePlan(String planId) => ApiClient.post('/api/plans/$planId/activate', {});

  static Future<void> updatePlan(String id, {required String name, String? description, String? icon}) =>
      ApiClient.put('/api/plans/$id', {'name': name, 'description': description, 'icon': icon});

  static Future<void> updateDay(String dayId, String title) =>
      ApiClient.put('/api/days/$dayId', {'title': title});

  static Future<void> addDay(String planId, String title) =>
      ApiClient.post('/api/plans/$planId/days', {'title': title});

  static Future<void> deleteDay(String dayId) => ApiClient.delete('/api/days/$dayId');

  static Future<void> addDayExercise(
    String dayId, {
    required String exerciseId,
    int? sets,
    int? reps,
    double? weight,
    int? rest,
  }) =>
      ApiClient.post('/api/days/$dayId/exercises', {
        'exerciseId': exerciseId,
        'targetSets': sets,
        'targetReps': reps,
        'targetWeight': weight,
        'restSeconds': rest,
      });

  static Future<void> deleteDayExercise(String id) => ApiClient.delete('/api/day-exercises/$id');

  /// Finish a workout → persist a session with per-set logs.
  /// [dayId] is null for a freestyle (planless) session. Each log: {exerciseId, setNo, weight, reps}.
  static Future<void> finishSession({
    String? dayId,
    required DateTime startedAt,
    required int durationMinutes,
    required List<Map<String, dynamic>> logs,
  }) =>
      ApiClient.post('/api/sessions', {
        'workoutDayId': dayId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'logs': logs,
      });

  static Future<void> deleteSession(String id) => ApiClient.delete('/api/sessions/$id');

  /// Latest performance of an exercise; null if never done.
  static Future<Map<String, dynamic>?> lastPerformance(String exerciseId) async {
    final data = await ApiClient.get('/api/sessions/last/$exerciseId');
    return data as Map<String, dynamic>?;
  }

  /// Personal record of an exercise; null if never lifted with weight.
  static Future<Map<String, dynamic>?> personalRecord(String exerciseId) async {
    final data = await ApiClient.get('/api/sessions/pr/$exerciseId');
    return data as Map<String, dynamic>?;
  }

  /// Per-session trend of an exercise (oldest→newest).
  static Future<List<dynamic>> trend(String exerciseId) async {
    final data = await ApiClient.get('/api/sessions/trend/$exerciseId') as Map<String, dynamic>?;
    return (data?['points'] as List<dynamic>?) ?? const [];
  }
}
