import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'measurement.dart';

/// All measurements, oldest → newest (backend orders by recordedAt asc).
final measurementsProvider = FutureProvider.autoDispose<List<Measurement>>((ref) async {
  final data = await ApiClient.get('/api/measurements') as List<dynamic>;
  return data.map((e) => Measurement.fromJson(e as Map<String, dynamic>)).toList();
});
