import 'package:flutter/material.dart';

/// 全屏图片查看器：双指缩放 / 拖动，多张图可左右滑动。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// 每张图各自一个变换控制器（用于判断是否已放大，放大时禁止翻页手势）
  late final List<TransformationController> _controllers = List.generate(
    widget.images.length,
    (_) => TransformationController(),
  );
  bool _zoomed = false;

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isZoomed(int i) => _controllers[i].value.getMaxScaleOnAxis() > 1.01;

  void _syncZoom() {
    final z = _isZoomed(_index);
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: widget.images.length,
        onPageChanged: (i) {
          setState(() {
            _index = i;
            _zoomed = _isZoomed(i);
          });
        },
        itemBuilder: (context, i) {
          return InteractiveViewer(
            transformationController: _controllers[i],
            minScale: 1,
            maxScale: 5,
            onInteractionEnd: (_) => _syncZoom(),
            child: SizedBox.expand(
              child: Image.network(
                widget.images[i],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  );
                },
                errorBuilder: (context, error, stack) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
