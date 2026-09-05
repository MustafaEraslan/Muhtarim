import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/work_post.dart';
import '../../services/muhtarim_service.dart';

class WorkPostsPage extends StatefulWidget {
  const WorkPostsPage({required this.user, required this.service, super.key});

  final AppUser user;
  final MuhtarimService service;

  @override
  State<WorkPostsPage> createState() => _WorkPostsPageState();
}

class _WorkPostsPageState extends State<WorkPostsPage> {
  late Future<List<WorkPost>> _future = widget.service.workPosts();

  Future<void> _refresh() async {
    setState(() => _future = widget.service.workPosts());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<WorkPost>>(
        future: _future,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? [];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Köyde yapılan çalışmalar',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kırklar Köyü için yapılan işleri fotoğraflarıyla takip edin',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (widget.user.isMukhtar) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _createPost,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Paylaş'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _WorkError(message: '${snapshot.error}', onRetry: _refresh)
              else if (posts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.construction_outlined, size: 42),
                        SizedBox(height: 10),
                        Text('Henüz çalışma paylaşılmadı.'),
                      ],
                    ),
                  ),
                )
              else
                ...posts.map((post) => _WorkPostCard(post: post)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createPost() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WorkPostForm(user: widget.user, service: widget.service),
    );
    if (created == true) await _refresh();
  }
}

class _WorkPostCard extends StatelessWidget {
  const _WorkPostCard({required this.post});
  final WorkPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              post.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const ColoredBox(
                      color: Color(0xFFE7E7E1),
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE7E7E1),
                child: Center(
                  child: Icon(Icons.broken_image_outlined, size: 42),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (post.isDemo)
                      const Chip(
                        avatar: Icon(Icons.science_outlined, size: 16),
                        label: Text('Demo'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(post.body),
                if (post.location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 17),
                      const SizedBox(width: 5),
                      Expanded(child: Text(post.location)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${post.ownerName} • ${DateFormat('dd.MM.yyyy HH:mm').format(post.occurredAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkPostForm extends StatefulWidget {
  const _WorkPostForm({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  State<_WorkPostForm> createState() => _WorkPostFormState();
}

class _WorkPostFormState extends State<_WorkPostForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late final _location = TextEditingController(
    text:
        '${widget.user.villageName}, ${widget.user.district} / ${widget.user.province}',
  );
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _extension = 'jpg';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Çalışma paylaş',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Fotoğrafın gerçek çalışmayı doğru biçimde gösterdiğinden emin olun.',
            ),
            const SizedBox(height: 16),
            if (_imageBytes == null)
              OutlinedButton.icon(
                onPressed: _busy ? null : _chooseSource,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Fotoğraf ekle'),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      onPressed: _busy ? null : _chooseSource,
                      icon: const Icon(Icons.edit),
                      tooltip: 'Fotoğrafı değiştir',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Çalışma başlığı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ne yapıldığını anlatın',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Konum'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.publish_outlined),
              label: Text(_busy ? 'Yükleniyor...' : 'Çalışmayı yayınla'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    final nameParts = picked.name.split('.');
    setState(() {
      _extension = nameParts.length > 1 ? nameParts.last : 'jpg';
    });
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _save() async {
    if (_imageBytes == null ||
        _title.text.trim().length < 2 ||
        _body.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf, başlık ve açıklama zorunludur.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.createWorkPost(
        user: widget.user,
        title: _title.text.trim(),
        body: _body.text.trim(),
        location: _location.text.trim(),
        imageBytes: _imageBytes!,
        fileExtension: _extension,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Paylaşım yüklenemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _WorkError extends StatelessWidget {
  const _WorkError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Çalışmalar alınamadı: $message'),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
