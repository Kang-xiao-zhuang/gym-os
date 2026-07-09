// Training-history models (mirror backend Session DTOs).

class WorkoutSessionSummary {
  WorkoutSessionSummary({
    required this.id,
    required this.createdAt,
    this.dayTitle,
    this.finishedAt,
    this.durationMinutes,
    this.exerciseCount = 0,
  });

  final String id;
  final DateTime createdAt;
  final String? dayTitle;
  final DateTime? finishedAt;
  final int? durationMinutes;
  final int exerciseCount;

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory WorkoutSessionSummary.fromJson(Map<String, dynamic> j) => WorkoutSessionSummary(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        dayTitle: j['dayTitle'] as String?,
        finishedAt: _dt(j['finishedAt']),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
        exerciseCount: (j['exerciseCount'] as num?)?.toInt() ?? 0,
      );

  DateTime get when => finishedAt ?? createdAt;
}

class LoggedExercise {
  LoggedExercise({required this.exerciseId, required this.name, this.bodyPart});
  final String exerciseId;
  final String name;
  final String? bodyPart;

  factory LoggedExercise.fromJson(Map<String, dynamic> j) => LoggedExercise(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String? ?? '动作',
        bodyPart: j['bodyPart'] as String?,
      );
}

class SessionDetail {
  SessionDetail({required this.id, this.dayTitle, this.durationMinutes, this.finishedAt, required this.exercises});
  final String id;
  final String? dayTitle;
  final int? durationMinutes;
  final DateTime? finishedAt;
  final List<LoggedExercise> exercises;

  factory SessionDetail.fromJson(Map<String, dynamic> j) => SessionDetail(
        id: j['id'] as String,
        dayTitle: j['dayTitle'] as String?,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt'] as String).toLocal(),
        exercises: (j['exercises'] as List<dynamic>? ?? [])
            .map((e) => LoggedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
