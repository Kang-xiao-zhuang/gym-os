// Month-calendar models (mirror backend CalendarDayResponse).

class CalendarDay {
  CalendarDay({
    required this.date,
    required this.bodyParts,
    required this.sets,
    required this.volume,
    this.durationMinutes,
    required this.sessionCount,
    required this.prCount,
    required this.exercises,
  });

  final DateTime date; // local date (midnight)
  final List<String> bodyParts; // distinct, ordered by sets desc
  final int sets;
  final double volume;
  final int? durationMinutes;
  final int sessionCount;
  final int prCount;
  final List<CalExercise> exercises;

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: DateTime.parse(j['date'] as String),
        bodyParts: (j['bodyParts'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        sets: (j['sets'] as num?)?.toInt() ?? 0,
        volume: (j['volume'] as num?)?.toDouble() ?? 0,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
        sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
        prCount: (j['prCount'] as num?)?.toInt() ?? 0,
        exercises: (j['exercises'] as List<dynamic>? ?? [])
            .map((e) => CalExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CalExercise {
  CalExercise({required this.exerciseId, required this.name, required this.bodyPart, required this.sets, this.topWeight, required this.reps});

  final String exerciseId;
  final String name;
  final String bodyPart;
  final int sets;
  final double? topWeight;
  final int reps;

  factory CalExercise.fromJson(Map<String, dynamic> j) => CalExercise(
        exerciseId: j['exerciseId'] as String? ?? '',
        name: j['name'] as String? ?? '动作',
        bodyPart: j['bodyPart'] as String? ?? '其他',
        sets: (j['sets'] as num?)?.toInt() ?? 0,
        topWeight: (j['topWeight'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt() ?? 0,
      );

  String get setsLabel {
    final w = topWeight;
    if (w != null && w > 0) {
      final ws = w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      return '$sets 组 · 最重 $ws kg';
    }
    return '$sets 组 · $reps 次';
  }
}
