import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _loadExercises() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final data = await ApiClient.get('/api/exercises') as List<dynamic>;
      final names = data.map((e) => e['name']).take(10).join('、');
      setState(() => _result = '后端返回 ${data.length} 个动作${names.isEmpty ? '（库为空）' : '：$names'}');
    } on ApiException catch (e) {
      setState(() => _error = '接口错误 [${e.code}] ${e.message}');
    } catch (e) {
      setState(() => _error = '请求失败：$e（后端是否已在 8866 启动？）');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text('已登录', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user?.email ?? '(无邮箱)', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _loading ? null : _loadExercises,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('带 Token 调后端 /api/exercises'),
                ),
                const SizedBox(height: 20),
                if (_loading) const CircularProgressIndicator(),
                if (_result != null)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(padding: const EdgeInsets.all(16), child: Text(_result!)),
                  ),
                if (_error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
