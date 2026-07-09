import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/body_part.dart';
import '../../core/theme.dart';
import 'exercise.dart';
import 'exercise_providers.dart';
import 'exercise_repository.dart';

class ExerciseFormPage extends ConsumerStatefulWidget {
  const ExerciseFormPage({super.key, this.exercise});

  /// null = 新增；非空 = 编辑。
  final Exercise? exercise;

  @override
  ConsumerState<ExerciseFormPage> createState() => _ExerciseFormPageState();
}

class _ExerciseFormPageState extends ConsumerState<ExerciseFormPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String? _bodyPart;
  String? _equipment;
  int _difficulty = 3;

  Uint8List? _pickedBytes;
  String? _pickedType;
  String? _existingImageUrl;
  bool _saving = false;

  bool get _isEdit => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    if (e != null) {
      _name.text = e.name;
      _desc.text = e.description ?? '';
      _bodyPart = e.bodyPart;
      _equipment = e.equipment;
      _difficulty = e.difficulty ?? 3;
      _existingImageUrl = e.imageUrl;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedType = picked.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _toast('请填写动作名称');
    if (_bodyPart == null) return _toast('请选择部位');
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'name': _name.text.trim(),
        'bodyPart': _bodyPart,
        'equipment': _equipment,
        'difficulty': _difficulty,
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'imageUrl': _existingImageUrl,
        'videoUrl': widget.exercise?.videoUrl,
      };

      if (_isEdit) {
        final id = widget.exercise!.id;
        if (_pickedBytes != null) {
          fields['imageUrl'] = await ExerciseRepository.uploadImage(id, _pickedBytes!, contentType: _pickedType!);
        }
        await ExerciseRepository.update(id, fields);
      } else {
        final id = await ExerciseRepository.create(fields);
        if (_pickedBytes != null) {
          final url = await ExerciseRepository.uploadImage(id, _pickedBytes!, contentType: _pickedType!);
          await ExerciseRepository.update(id, {...fields, 'imageUrl': url});
        }
      }
      ref.invalidate(exerciseListProvider);
      if (mounted) {
        _toast(_isEdit ? '已保存 ✅' : '已添加 ✅');
        context.go('/exercises');
      }
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除动作'),
        content: Text('确定删除「${widget.exercise!.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ExerciseRepository.remove(widget.exercise!.id);
      ref.invalidate(exerciseListProvider);
      if (mounted) {
        _toast('已删除');
        context.go('/exercises');
      }
    } catch (e) {
      _toast('删除失败：$e');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑动作' : '新增动作'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pad),
        children: [
          _imagePicker(),
          const SizedBox(height: 20),
          _label('动作名称'),
          TextField(controller: _name, decoration: const InputDecoration(hintText: '例如：杠铃卧推')),
          const SizedBox(height: 20),
          _label('部位'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBodyParts.map((bp) {
              final s = bodyPartStyle(bp);
              final selected = _bodyPart == bp;
              return ChoiceChip(
                label: Text('${s.emoji} $bp'),
                selected: selected,
                selectedColor: s.color.withValues(alpha: 0.18),
                onSelected: (_) => setState(() => _bodyPart = bp),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('器械'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kEquipments.map((eq) {
              return ChoiceChip(
                label: Text(eq),
                selected: _equipment == eq,
                onSelected: (sel) => setState(() => _equipment = sel ? eq : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('难度'),
          Row(
            children: List.generate(5, (i) {
              final active = i < _difficulty;
              return GestureDetector(
                onTap: () => setState(() => _difficulty = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Opacity(opacity: active ? 1 : 0.25, child: const Text('🔥', style: TextStyle(fontSize: 30))),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _label('动作说明'),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '怎么做、注意要点…'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? '保存' : '添加'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _imagePicker() {
    final color = _bodyPart != null ? bodyPartStyle(_bodyPart!).color : const Color(0xFF6366F1);
    Widget content;
    if (_pickedBytes != null) {
      content = Image.memory(_pickedBytes!, fit: BoxFit.cover);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      content = Image.network(_existingImageUrl!, fit: BoxFit.cover);
    } else {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 40, color: color),
            const SizedBox(height: 6),
            Text('添加示范图（可选）', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _pickImage,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: content,
        ),
      ),
    );
  }
}
