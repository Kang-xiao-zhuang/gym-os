// Training-history models (mirror backend Session DTOs).

class WorkoutSessionSummary {
  WorkoutSessionSummary({
    required this.id,
    required this.createdAt,
    this.dayTitle,
    this.finishedAt,
    this.durationMinutes,
    this.totalSets = 0,
    this.totalVolume = 0,
    this.exerciseCount = 0,
    this.prCount = 0,
  });

  final String id;
  final DateTime createdAt;
  final String? dayTitle;
  final DateTime? finishedAt;
  final int? durationMinutes;
  final int totalSets;
  final double totalVolume;
  final int exerciseCount;

  /// How many exercises set a new personal record in this session.
  final int prCount;

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory WorkoutSessionSummary.fromJson(Map<String, dynamic> j) => WorkoutSessionSummary(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        dayTitle: j['dayTitle'] as String?,
        finishedAt: _dt(j['finishedAt']),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
        totalSets: (j['totalSets'] as num?)?.toInt() ?? 0,
        totalVolume: (j['totalVolume'] as num?)?.toDouble() ?? 0,
        exerciseCount: (j['exerciseCount'] as num?)?.toInt() ?? 0,
        prCount: (j['prCount'] as num?)?.toInt() ?? 0,
      );

  DateTime get when => finishedAt ?? createdAt;
}

/// Coaching insights (mirrors backend InsightsResponse).
class Insights {
  Insights({required this.bodyParts, required this.plateaus, this.biggestGain});

  final List<BodyPartLoad> bodyParts;
  final List<Plateau> plateaus;
  final Gain? biggestGain;

  bool get isEmpty => bodyParts.isEmpty && plateaus.isEmpty && biggestGain == null;

  factory Insights.fromJson(Map<String, dynamic> j) => Insights(
        bodyParts: (j['bodyParts'] as List<dynamic>? ?? [])
            .map((e) => BodyPartLoad.fromJson(e as Map<String, dynamic>))
            .toList(),
        plateaus: (j['plateaus'] as List<dynamic>? ?? [])
            .map((e) => Plateau.fromJson(e as Map<String, dynamic>))
            .toList(),
        biggestGain: j['biggestGain'] == null ? null : Gain.fromJson(j['biggestGain'] as Map<String, dynamic>),
      );
}

class BodyPartLoad {
  BodyPartLoad({required this.bodyPart, required this.sets});
  final String bodyPart;
  final int sets;
  factory BodyPartLoad.fromJson(Map<String, dynamic> j) =>
      BodyPartLoad(bodyPart: j['bodyPart'] as String? ?? '其他', sets: (j['sets'] as num?)?.toInt() ?? 0);
}

class Plateau {
  Plateau({required this.exerciseName, required this.weight, required this.sessions});
  final String exerciseName;
  final double weight;
  final int sessions;
  factory Plateau.fromJson(Map<String, dynamic> j) => Plateau(
        exerciseName: j['exerciseName'] as String? ?? '动作',
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
      );
}

class Gain {
  Gain({required this.exerciseName, required this.fromWeight, required this.toWeight, required this.delta});
  final String exerciseName;
  final double fromWeight;
  final double toWeight;
  final double delta;
  factory Gain.fromJson(Map<String, dynamic> j) => Gain(
        exerciseName: j['exerciseName'] as String? ?? '动作',
        fromWeight: (j['fromWeight'] as num?)?.toDouble() ?? 0,
        toWeight: (j['toWeight'] as num?)?.toDouble() ?? 0,
        delta: (j['delta'] as num?)?.toDouble() ?? 0,
      );
}

class SetLog {
  SetLog({this.setNo, this.weight, this.reps});
  final int? setNo;
  final double? weight;
  final int? reps;

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        setNo: (j['setNo'] as num?)?.toInt(),
        weight: (j['weight'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
      );

  String get label {
    final w = weight == null ? null : (weight! % 1 == 0 ? weight!.toStringAsFixed(0) : weight!.toStringAsFixed(1));
    if (w != null && reps != null) return '$w kg × $reps';
    if (reps != null) return '× $reps';
    return '—';
  }
}

class ExerciseLog {
  ExerciseLog({required this.exerciseId, required this.name, this.bodyPart, required this.sets});
  final String exerciseId;
  final String name;
  final String? bodyPart;
  final List<SetLog> sets;

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String? ?? '动作',
        bodyPart: j['bodyPart'] as String?,
        sets: (j['sets'] as List<dynamic>? ?? []).map((e) => SetLog.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SessionDetail {
  SessionDetail({
    required this.id,
    this.dayTitle,
    this.durationMinutes,
    this.finishedAt,
    this.totalSets = 0,
    this.totalVolume = 0,
    required this.exercises,
  });

  final String id;
  final String? dayTitle;
  final int? durationMinutes;
  final DateTime? finishedAt;
  final int totalSets;
  final double totalVolume;
  final List<ExerciseLog> exercises;

  factory SessionDetail.fromJson(Map<String, dynamic> j) => SessionDetail(
        id: j['id'] as String,
        dayTitle: j['dayTitle'] as String?,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt'] as String).toLocal(),
        totalSets: (j['totalSets'] as num?)?.toInt() ?? 0,
        totalVolume: (j['totalVolume'] as num?)?.toDouble() ?? 0,
        exercises: (j['exercises'] as List<dynamic>? ?? [])
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
