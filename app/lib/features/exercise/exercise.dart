/// A single exercise from the backend `/api/exercises`.
class Exercise {
  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    this.equipment,
    this.difficulty,
    this.description,
    this.imageUrl,
    this.videoUrl,
  });

  final String id;
  final String name;
  final String bodyPart;
  final String? equipment;
  final int? difficulty;
  final String? description;
  final String? imageUrl;
  final String? videoUrl;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      bodyPart: json['bodyPart'] as String,
      equipment: json['equipment'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
    );
  }
}
