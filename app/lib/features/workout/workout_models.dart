// Models for the training-plan module: Plan → Day → DayExercise.

/// Preset emoji icons users can pick for a plan.
const List<String> kPlanIcons = [
  '📅', '💪', '🔥', '🏋️', '🦾', '🦵', '🎯', '⚡', '🏆', '🧘', '🚴', '🏃'
];

class Plan {
  Plan({required this.id, required this.name, this.description, this.totalWeeks, this.isActive, this.icon});

  final String id;
  final String name;
  final String? description;
  final int? totalWeeks;
  final bool? isActive;
  final String? icon;

  String get displayIcon => (icon != null && icon!.isNotEmpty) ? icon! : '📅';

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        totalWeeks: (j['totalWeeks'] as num?)?.toInt(),
        isActive: j['isActive'] as bool?,
        icon: j['icon'] as String?,
      );
}

class Day {
  Day({required this.id, this.weekNo, this.dayNo, this.title});

  final String id;
  final int? weekNo;
  final int? dayNo;
  final String? title;

  factory Day.fromJson(Map<String, dynamic> j) => Day(
        id: j['id'] as String,
        weekNo: (j['weekNo'] as num?)?.toInt(),
        dayNo: (j['dayNo'] as num?)?.toInt(),
        title: j['title'] as String?,
      );

  String get label => (title != null && title!.isNotEmpty) ? title! : '第 ${dayNo ?? '-'} 天';
}

class DayExercise {
  DayExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.bodyPart,
    this.imageUrl,
    this.targetSets,
    this.targetReps,
    this.targetWeight,
    this.restSeconds,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final String? bodyPart;
  final String? imageUrl;
  final int? targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? restSeconds;

  factory DayExercise.fromJson(Map<String, dynamic> j) => DayExercise(
        id: j['id'] as String,
        exerciseId: j['exerciseId'] as String,
        exerciseName: j['exerciseName'] as String? ?? '(动作)',
        bodyPart: j['bodyPart'] as String?,
        imageUrl: j['imageUrl'] as String?,
        targetSets: (j['targetSets'] as num?)?.toInt(),
        targetReps: (j['targetReps'] as num?)?.toInt(),
        targetWeight: (j['targetWeight'] as num?)?.toDouble(),
        restSeconds: (j['restSeconds'] as num?)?.toInt(),
      );

  String get volume {
    final parts = <String>[];
    if (targetSets != null && targetReps != null) parts.add('$targetSets × $targetReps');
    if (targetWeight != null) parts.add('${targetWeight!.toStringAsFixed(targetWeight! % 1 == 0 ? 0 : 1)} kg');
    return parts.join(' · ');
  }
}
