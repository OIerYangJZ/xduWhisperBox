import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

class ImageGallery extends StatelessWidget {
  const ImageGallery({
    super.key,
    required this.images,
    this.onRemove,
  });

  final List<String> images;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          '图片（${images.length}）',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (BuildContext context, int index) {
            return _ImageTile(
              imageUrl: images[index],
              onTap: () => _showImageViewer(context, index),
            );
          },
        ),
      ],
    );
  }

  void _showImageViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _ImageViewerPage(
              images: images,
              initialIndex: initialIndex,
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final VoidCallback onTap;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    const Widget errorPlaceholder = ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, color: Colors.black38, size: 32),
            SizedBox(height: 4),
            Text(
              '加载失败',
              style: TextStyle(color: Colors.black45, fontSize: 10),
            ),
          ],
        ),
      ),
    );
    const Widget loadingPlaceholder = ColoredBox(
      color: Colors.black12,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    if (widget.imageUrl.startsWith('data:')) {
      final int commaIndex = widget.imageUrl.indexOf(',');
      if (commaIndex != -1) {
        final String base64Data = widget.imageUrl.substring(commaIndex + 1);
        try {
          return Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (BuildContext context, Object error,
                StackTrace? stackTrace) {
              return errorPlaceholder;
            },
          );
        } catch (_) {
          return errorPlaceholder;
        }
      }
    }

    final String resolvedUrl = AppConfig.resolveUrl(widget.imageUrl);
    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        return loadingProgress == null ? child : loadingPlaceholder;
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        return errorPlaceholder;
      },
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片页面
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: _ViewerImage(imageUrl: widget.images[index]),
                ),
              );
            },
          ),
          // 顶部关闭按钮和指示器（与移动端一致的样式）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerImage extends StatefulWidget {
  const _ViewerImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  @override
  Widget build(BuildContext context) {
    const Widget errorPlaceholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
        SizedBox(height: 16),
        Text(
          '图片加载失败',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
    const Widget loadingPlaceholder =
        CircularProgressIndicator(color: Colors.white);

    if (widget.imageUrl.startsWith('data:')) {
      final int commaIndex = widget.imageUrl.indexOf(',');
      if (commaIndex != -1) {
        final String base64Data = widget.imageUrl.substring(commaIndex + 1);
        try {
          return Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.contain,
            errorBuilder: (BuildContext context, Object error,
                StackTrace? stackTrace) {
              return errorPlaceholder;
            },
          );
        } catch (_) {
          return errorPlaceholder;
        }
      }
    }

    final String resolvedUrl = AppConfig.resolveUrl(widget.imageUrl);
    return Image.network(
      resolvedUrl,
      fit: BoxFit.contain,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        return loadingProgress == null ? child : loadingPlaceholder;
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        return errorPlaceholder;
      },
    );
  }
}
