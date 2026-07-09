import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/theme_mode_provider.dart';
import 'profile_providers.dart';

/// The "我的" tab: account info, edit profile, 动作库, logout.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final name = displayName(user);
    final avatar = avatarUrl(user);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pad),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 24))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  tooltip: '编辑资料',
                  onPressed: () => context.push('/profile-edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dark_mode_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text('外观', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                        ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('编辑资料'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile-edit'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('🏆', style: TextStyle(fontSize: 20)),
                  title: const Text('训练历史'),
                  subtitle: const Text('回看每次训练'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/history'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('📈', style: TextStyle(fontSize: 20)),
                  title: const Text('训练统计'),
                  subtitle: const Text('周统计与打卡日历'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/stats'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('💪', style: TextStyle(fontSize: 20)),
                  title: const Text('动作库'),
                  subtitle: const Text('管理训练动作'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/exercises'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red.shade400),
                  title: Text('退出登录', style: TextStyle(color: Colors.red.shade400)),
                  onTap: () => Supabase.instance.client.auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
