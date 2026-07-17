import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/theme_mode_provider.dart';
import '../history/session_providers.dart';
import 'data_export.dart';
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
                      ? Text(name.characters.isEmpty ? '?' : name.characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 24))
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
                  leading: const Text('🏅', style: TextStyle(fontSize: 20)),
                  title: const Text('成就徽章'),
                  subtitle: const Text('解锁你的训练里程碑'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/achievements'),
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
                  leading: const Text('📤', style: TextStyle(fontSize: 20)),
                  title: const Text('导出训练数据'),
                  subtitle: const Text('CSV 表格 / JSON 备份'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('📥', style: TextStyle(fontSize: 20)),
                  title: const Text('导入训练数据'),
                  subtitle: const Text('从 JSON 备份恢复（自动跳过重复）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _import(context, ref),
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

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('📊', style: TextStyle(fontSize: 20)),
              title: const Text('CSV 表格'),
              subtitle: const Text('每组一行，Excel 可打开'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _run(context, exportTrainingCsv, (n) => n == 0 ? '暂无训练数据可导出' : '已导出 $n 条记录 📤');
              },
            ),
            ListTile(
              leading: const Text('🗄️', style: TextStyle(fontSize: 20)),
              title: const Text('JSON 备份'),
              subtitle: const Text('完整结构，可回导恢复'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _run(context, exportTrainingJson, (n) => n == 0 ? '暂无训练数据可导出' : '已备份 $n 次训练 🗄️');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<int> Function() action, String Function(int) msg) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('处理中…')));
    try {
      final n = await action();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(msg(n))));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('导入训练数据'),
        content: const Text('从 JSON 备份恢复训练记录。\n重复的训练会自动跳过，缺失的动作会自动创建。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('选择文件')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await importTrainingJson();
      if (r.cancelled) return;
      ref.invalidate(sessionsProvider);
      ref.invalidate(insightsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('导入完成：新增 ${r.imported}，跳过重复 ${r.skipped}'
            '${r.exercisesCreated > 0 ? '，新建动作 ${r.exercisesCreated}' : ''} ✅'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }
}
