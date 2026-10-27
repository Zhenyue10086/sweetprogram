import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/data_service.dart';
import '../services/storage_service.dart';
import '../utils.dart';
import 'image_viewer_page.dart';

/// 动态页面：朋友圈式分享（文字 + 图片 + 点赞 + 评论回复）
class MomentPage extends StatefulWidget {
  const MomentPage({super.key});

  @override
  State<MomentPage> createState() => _MomentPageState();
}

class _MomentPageState extends State<MomentPage> {
  DataService get ds => DataService.instance;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _showPublishSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PublishSheet(),
    );
  }

  Future<void> _refresh() async {
    if (ds.cloudAvailable) {
      await ds.pullFromCloud();
    } else {
      _toast('云端未连接，仅显示本地内容');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.lightBlue,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPublishSheet,
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListenableBuilder(
        listenable: ds,
        builder: (context, _) {
          if (ds.moments.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      '还没有动态，点右下角 + 记录你们的第一条甜蜜吧～',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ds.moments.length,
              itemBuilder: (context, index) =>
                  _MomentCard(moment: ds.moments[index], index: index),
            ),
          );
        },
      ),
    );
  }
}

/// 发布动态的底部弹窗（可编辑文字 + 选择多张图片）
class PublishSheet extends StatefulWidget {
  const PublishSheet({super.key});

  @override
  State<PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<PublishSheet> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _uploading = false;

  DataService get ds => DataService.instance;

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked.isNotEmpty) {
        setState(() {
          // 最多 9 张
          _images.addAll(picked.take(9 - _images.length));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择图片失败，请重试')),
        );
      }
    }
  }

  Future<void> _publish() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点什么或选张图片吧～')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      // 上传图片到 CloudBase 云存储
      final urls = <String>[];
      for (final img in _images) {
        final bytes = await img.readAsBytes();
        final url = await StorageService.upload(bytes);
        urls.add(url);
      }
      await ds.addMoment(content, urls, ds.nickname);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布成功 ❤️'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败：$e\n（图片需联网并配置 Storage 桶）'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '发布动态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '分享此刻的心情...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_images[i].path),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 90,
                              height: 90,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _uploading ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('添加图片'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _uploading ? null : _publish,
                    child: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('发布'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单条动态卡片
class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment, required this.index});

  final Map<String, dynamic> moment;
  final int index;

  DataService get ds => DataService.instance;

  @override
  Widget build(BuildContext context) {
    final id = moment['id'].toString();
    final author = moment['author']?.toString() ?? '我';
    final content = moment['content']?.toString() ?? '';
    final images = (moment['images'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final comments = (moment['comments'] as List?) ?? const [];
    final likes = (moment['likes'] as num?)?.toInt() ?? 0;
    final created = tryParseTime(moment['created_at']) ?? DateTime.now();
    final liked = ds.isLiked(id);
    final avatarUrl = ds.avatarForMoment(moment);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.lightBlue.shade100,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.lightBlue)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    Text(
                      formatRelativeTime(created),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除动态'),
                      content: const Text('确定删除这条动态吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ds.deleteMoment(id);
                          },
                          child: const Text('删除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImages(context, images),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(
                context,
                icon: liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? Colors.redAccent : Colors.grey,
                label: likes > 0 ? '$likes' : '赞',
                onTap: () => ds.toggleLike(id),
              ),
              const SizedBox(width: 20),
              _actionButton(
                context,
                icon: Icons.comment_outlined,
                color: Colors.grey,
                label: comments.isNotEmpty ? '${comments.length}' : '评论',
                onTap: () => _showComments(context, id),
              ),
            ],
          ),
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in comments.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${c['author'] ?? '我'}：',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.lightBlue,
                              ),
                            ),
                            if (c['reply_to'] != null)
                              TextSpan(
                                text: '回复 @${c['reply_to']} ',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            TextSpan(
                              text: c['content']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (comments.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => _showComments(context, id),
                        child: Text(
                          '查看全部 ${comments.length} 条评论',
                          style: const TextStyle(fontSize: 12, color: Colors.lightBlue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context, List<String> urls) {
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => _openViewer(context, urls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _networkImage(urls.first, height: 220, width: double.infinity),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _openViewer(context, urls, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _networkImage(urls[i], height: 100, width: 100),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ImageViewerPage(images: urls, initialIndex: index),
      ),
    );
  }

  Widget _networkImage(String url, {required double height, required double width}) {
    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          width: width,
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  void _showComments(BuildContext context, String momentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(momentId: momentId),
    );
  }
}

/// 评论弹窗（支持回复 + 删除）
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.momentId});

  final String momentId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  String? _replyTo; // 回复对象的昵称

  DataService get ds => DataService.instance;

  Map<String, dynamic>? get _moment {
    try {
      return ds.moments.firstWhere((e) => e['id'] == widget.momentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: ds,
          builder: (context, _) {
            final moment = _moment;
            if (moment == null) {
              return const SizedBox(height: 100);
            }
            final comments = (moment['comments'] as List?) ?? const [];
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          '评论',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        if (_replyTo != null)
                          Text(
                            '回复 @$_replyTo',
                            style: const TextStyle(fontSize: 13, color: Colors.lightBlue),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text('暂无评论，快来抢沙发～', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: comments.length,
                            itemBuilder: (context, i) {
                              final c = Map<String, dynamic>.from(comments[i] as Map);
                              return ListTile(
                                dense: true,
                                onTap: () {
                                  setState(() => _replyTo = c['author']?.toString());
                                },
                                title: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: c['author']?.toString() ?? '我',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.lightBlue,
                                        ),
                                      ),
                                      if (c['reply_to'] != null)
                                        TextSpan(
                                          text: ' 回复 @${c['reply_to']}',
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                subtitle: Text(
                                  c['content']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                  onPressed: () =>
                                      ds.deleteComment(widget.momentId, c['id'].toString()),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: _replyTo == null ? '说点什么...' : '回复 @$_replyTo...',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            ds.addComment(
                              widget.momentId,
                              text,
                              ds.nickname,
                              replyTo: _replyTo,
                            );
                            _controller.clear();
                            setState(() => _replyTo = null);
                          },
                          child: const Text('发送'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
