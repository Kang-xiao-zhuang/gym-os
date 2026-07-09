import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'exercise.dart';

/// Fetches the exercise library from the backend. Auto-disposed so it re-fetches
/// each time the list page is entered; call `ref.invalidate` to force a refresh.
final exerciseListProvider = FutureProvider.autoDispose<List<Exercise>>((ref) async {
  final data = await ApiClient.get('/api/exercises') as List<dynamic>;
  return data
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});
