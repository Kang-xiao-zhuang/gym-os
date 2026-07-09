import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile edits go straight to Supabase Auth user_metadata (nickname/avatar);
/// avatar images live in Supabase Storage. No backend involved.
class ProfileRepository {
  static const _bucket = 'exercise-media';

  static Future<String> uploadAvatar(Uint8List bytes, {required String contentType}) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final storage = Supabase.instance.client.storage.from(_bucket);
    final path = 'avatars/$userId';
    await storage.uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
    return '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> update({required String nickname, String? avatar}) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {
        'nickname': nickname,
        'avatar': ?avatar,
      }),
    );
  }
}
