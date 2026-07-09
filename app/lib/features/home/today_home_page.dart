import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../workout/today_section.dart';

/// The "今天" tab: greeting + today's workout.
class TodayHomePage extends ConsumerWidget {
  const TodayHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['nickname'] as String?)?.trim();
    final display =
        (name != null && name.isNotEmpty) ? name : (user?.email?.split('@').first ?? '训练者');

    final h = DateTime.now().hour;
    final greet = h < 6
        ? '凌晨好'
        : h < 12
            ? '早上好'
            : h < 14
                ? '中午好'
                : h < 18
                    ? '下午好'
                    : '晚上好';
    final greetEmoji = h < 12 ? '🌅' : (h < 18 ? '☀️' : '🌙');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.pad, 12, AppTheme.pad, AppTheme.pad),
          children: [
            Text('$greetEmoji  $greet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 2),
            Text(display,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.pad),
            const TodaySection(),
          ],
        ),
      ),
    );
  }
}
