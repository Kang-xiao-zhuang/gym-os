import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../workout/today_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['nickname'] as String?)?.trim();
    final display = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? '训练者');

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
          padding: const EdgeInsets.fromLTRB(AppTheme.pad, 8, AppTheme.pad, AppTheme.pad),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greetEmoji  $greet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(display,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '退出登录',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.pad),
            const TodaySection(),
            const SizedBox(height: 24),
            Text('  快捷入口', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.gap),
            _FeatureCard(
              emoji: '💪',
              color: const Color(0xFF6366F1),
              title: '动作库',
              subtitle: '浏览训练动作，配上示范图',
              onTap: () => context.push('/exercises'),
            ),
            const SizedBox(height: AppTheme.gap),
            _FeatureCard(
              emoji: '📅',
              color: const Color(0xFFF97316),
              title: '训练计划',
              subtitle: '编排每天要练的动作',
              onTap: () => context.push('/plans'),
            ),
            const SizedBox(height: AppTheme.gap),
            _FeatureCard(
              emoji: '📊',
              color: const Color(0xFF14B8A6),
              title: '身体数据',
              subtitle: '记录体重、围度、体脂',
              comingSoon: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  final String emoji;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: comingSoon ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pad),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('即将上线', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                )
              else
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
