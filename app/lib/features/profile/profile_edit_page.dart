import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import 'profile_providers.dart';
import 'profile_repository.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _nick;
  Uint8List? _pickedBytes;
  String? _pickedType;
  String? _existingAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authUserProvider).value;
    _nick = TextEditingController(text: displayName(user));
    _existingAvatar = avatarUrl(user);
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedType = picked.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (_nick.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    setState(() => _saving = true);
    try {
      String? avatar;
      if (_pickedBytes != null) {
        avatar = await ProfileRepository.uploadAvatar(_pickedBytes!, contentType: _pickedType!);
      }
      await ProfileRepository.update(nickname: _nick.text.trim(), avatar: avatar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存 ✅')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pad),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    backgroundImage: _pickedBytes != null
                        ? MemoryImage(_pickedBytes!)
                        : (_existingAvatar != null ? NetworkImage(_existingAvatar!) : null) as ImageProvider?,
                    child: (_pickedBytes == null && _existingAvatar == null)
                        ? const Icon(Icons.person, size: 44, color: Color(0xFF6366F1))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('点头像更换', style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 24),
          const Text('昵称', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _nick, decoration: const InputDecoration(hintText: '给自己起个名字')),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
