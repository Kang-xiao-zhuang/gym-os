import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'session_models.dart';

final sessionsProvider = FutureProvider.autoDispose<List<WorkoutSessionSummary>>((ref) async {
  ref.keepAlive(); // cache across tab switches; refreshed via ref.invalidate on new/deleted sessions
  final data = await ApiClient.get('/api/sessions') as List<dynamic>;
  return data.map((e) => WorkoutSessionSummary.fromJson(e as Map<String, dynamic>)).toList();
});

final sessionDetailProvider = FutureProvider.autoDispose.family<SessionDetail, String>((ref, id) async {
  final data = await ApiClient.get('/api/sessions/$id') as Map<String, dynamic>;
  return SessionDetail.fromJson(data);
});

final insightsProvider = FutureProvider.autoDispose<Insights>((ref) async {
  ref.keepAlive(); // cache across visits; invalidated when a workout is finished
  final data = await ApiClient.get('/api/sessions/insights') as Map<String, dynamic>;
  return Insights.fromJson(data);
});
