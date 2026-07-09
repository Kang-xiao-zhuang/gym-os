import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';

/// Storage + backend operations for exercises.
class ExerciseRepository {
  static const _bucket = 'exercise-media';

  /// Upload [bytes] to Supabase Storage under a stable path for [exerciseId],
  /// then return the public URL (with a cache-busting query so a replaced image
  /// shows immediately).
  static Future<String> uploadImage(
    String exerciseId,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final path = 'exercises/$exerciseId';
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: contentType),
    );
    final url = storage.getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create an exercise; returns the new id.
  static Future<String> create(Map<String, dynamic> fields) async {
    final data = await ApiClient.post('/api/exercises', fields) as Map<String, dynamic>;
    return data['id'] as String;
  }

  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await ApiClient.put('/api/exercises/$id', fields);
  }

  static Future<void> remove(String id) async {
    await ApiClient.delete('/api/exercises/$id');
  }
}
