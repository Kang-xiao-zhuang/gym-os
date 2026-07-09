import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import 'exercise.dart';
import 'exercise_providers.dart';
import 'exercise_repository.dart';

class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  late String? _imageUrl = widget.exercise.imageUrl;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ExerciseRepository.uploadImage(
        widget.exercise.id,
        bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      await ExerciseRepository.updateImageUrl(widget.exercise, url);
      ref.invalidate(exerciseListProvider);
      if (mounted) setState(() => _imageUrl = url);
      _toast('图片已更新');
    } catch (e) {
      _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pad),
        children: [
          _ImageHeader(url: _imageUrl, uploading: _uploading),
          const SizedBox(height: AppTheme.gap),
          FilledButton.tonalIcon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_imageUrl == null ? '上传图片' : '更换图片'),
          ),
          const SizedBox(height: AppTheme.pad),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(e.bodyPart, scheme.primary),
              if (e.equipment != null) _Tag(e.equipment!, scheme.tertiary),
              _Tag('难度 ${e.difficulty ?? '-'}', scheme.secondary),
            ],
          ),
          if (e.description != null) ...[
            const SizedBox(height: AppTheme.pad),
            Text('动作说明', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(e.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({this.url, required this.uploading});

  final String? url;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url!.isNotEmpty)
              Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(scheme),
              )
            else
              _placeholder(scheme),
            if (uploading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
        child: Icon(Icons.fitness_center, size: 56, color: scheme.primary.withValues(alpha: 0.4)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
