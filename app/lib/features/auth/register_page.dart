import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        // Passed to auth.users.raw_user_meta_data; a DB trigger can copy it into public.users.
        data: {'nickname': _nickname.text.trim()},
      );
      if (res.session == null) {
        // Email confirmation is still on: no session yet.
        _toast('注册成功，请先到邮箱确认后再登录');
        if (mounted) context.go('/login');
      }
      // Otherwise the router navigates to '/' automatically.
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('注册失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nickname,
                    decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? '请输入有效邮箱' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? '密码至少 6 位' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _signUp,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('注册并登录'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => context.go('/login'),
                    child: const Text('已有账号？去登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
