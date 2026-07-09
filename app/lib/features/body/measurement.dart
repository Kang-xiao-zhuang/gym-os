// Body measurement model (mirrors backend MeasurementResponse).

class Measurement {
  Measurement({
    required this.id,
    required this.recordedAt,
    this.weight,
    this.bodyFat,
    this.chest,
    this.waist,
    this.hip,
    this.armLeft,
    this.thighLeft,
  });

  final String id;
  final DateTime recordedAt;
  final double? weight;
  final double? bodyFat;
  final double? chest;
  final double? waist;
  final double? hip;
  final double? armLeft;
  final double? thighLeft;

  static double? _d(dynamic v) => (v as num?)?.toDouble();

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        id: j['id'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String).toLocal(),
        weight: _d(j['weight']),
        bodyFat: _d(j['bodyFat']),
        chest: _d(j['chest']),
        waist: _d(j['waist']),
        hip: _d(j['hip']),
        armLeft: _d(j['armLeft']),
        thighLeft: _d(j['thighLeft']),
      );
}
