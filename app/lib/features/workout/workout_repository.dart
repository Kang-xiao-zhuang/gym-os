import '../../core/api_client.dart';

/// Backend calls for the training-plan module.
class WorkoutRepository {
  static Future<void> createPlan(String name, String? description) =>
      ApiClient.post('/api/plans', {'name': name, 'description': description});

  static Future<void> deletePlan(String planId) => ApiClient.delete('/api/plans/$planId');

  static Future<void> activatePlan(String planId) => ApiClient.post('/api/plans/$planId/activate', {});

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

  /// Finish today's workout → persist a session with per-set logs.
  /// Each log: {exerciseId, setNo, weight, reps}.
  static Future<void> finishSession({
    required String dayId,
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
}
