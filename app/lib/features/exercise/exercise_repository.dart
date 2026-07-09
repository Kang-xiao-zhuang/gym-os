import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import 'exercise.dart';

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

  /// PUT the exercise back to the backend with a new [imageUrl].
  static Future<void> updateImageUrl(Exercise e, String imageUrl) async {
    await ApiClient.put('/api/exercises/${e.id}', {
      'name': e.name,
      'bodyPart': e.bodyPart,
      'equipment': e.equipment,
      'difficulty': e.difficulty,
      'description': e.description,
      'imageUrl': imageUrl,
      'videoUrl': e.videoUrl,
    });
  }
}
