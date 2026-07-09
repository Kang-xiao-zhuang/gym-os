import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The current Supabase user, re-emitted on every auth change (incl. profile
/// updates), so the UI reflects nickname/avatar edits immediately.
final authUserProvider = StreamProvider<User?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser;
  await for (final _ in auth.onAuthStateChange) {
    yield auth.currentUser;
  }
});

String displayName(User? user) {
  final nick = (user?.userMetadata?['nickname'] as String?)?.trim();
  if (nick != null && nick.isNotEmpty) return nick;
  return user?.email?.split('@').first ?? '训练者';
}

String? avatarUrl(User? user) {
  final a = (user?.userMetadata?['avatar'] as String?)?.trim();
  return (a != null && a.isNotEmpty) ? a : null;
}
