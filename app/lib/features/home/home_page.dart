import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GymOS'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.email ?? '(无邮箱)'),
              subtitle: const Text('已登录'),
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.fitness_center,
            title: '动作库',
            subtitle: '浏览训练动作',
            onTap: () => context.push('/exercises'),
          ),
          _FeatureCard(
            icon: Icons.event_note,
            title: '训练计划',
            subtitle: '即将上线',
            enabled: false,
          ),
          _FeatureCard(
            icon: Icons.monitor_weight,
            title: '身体数据',
            subtitle: '即将上线',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: enabled ? Colors.indigo : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
