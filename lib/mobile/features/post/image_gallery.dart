import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';

/// 图片画廊组件
/// 支持点击放大、手势缩放、滑动切换
class ImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  /// 显示全屏画廊
  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ImageGallery(
              imageUrls: imageUrls,
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

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _fullUrls;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fullUrls = widget.imageUrls.map((url) {
      return url.startsWith('http') ? url : AppConfig.resolveUrl(url);
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Future<void> _saveCurrentImage() async {
    if (_isSaving || _fullUrls.isEmpty) {
      return;
    }
    if (kIsWeb) {
      _showMessage('请在浏览器中长按图片保存');
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess();
        if (!granted) {
          _showMessage('未获得相册权限，无法保存图片');
          return;
        }
      }

      final Uri uri = Uri.parse(_fullUrls[_currentIndex]);
      final http.Response response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('download failed: ${response.statusCode}');
      }

      final String fileName =
          'xdu_treehole_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Gal.putImageBytes(
        response.bodyBytes,
        name: fileName,
        album: '西电树洞',
      );
      _showMessage('图片已保存到相册');
    } catch (_) {
      _showMessage('保存失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 图片页面
          PageView.builder(
            controller: _pageController,
            itemCount: _fullUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _ImagePage(
                url: _fullUrls[index],
                onTap: _close,
                onLongPress: _saveCurrentImage,
              );
            },
          ),

          // 顶部关闭按钮和指示器
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 关闭按钮
                    GestureDetector(
                      onTap: _close,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    // 页码指示器
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_fullUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // 占位保持对称
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),

          // 底部缩略图预览
          if (_fullUrls.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _fullUrls.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? MobileTheme.primaryOf(context)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Opacity(
                              opacity: isSelected ? 1.0 : 0.5,
                              child: CachedNetworkImage(
                                imageUrl: _fullUrls[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[800]),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ImagePage({
    required this.url,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: () {
        // 双击放大
      },
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

/// 帖子图片网格组件
class PostImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final int maxDisplay;

  const PostImageGrid({
    super.key,
    required this.imageUrls,
    this.maxDisplay = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final displayUrls = imageUrls.take(maxDisplay).toList();
    final remaining = imageUrls.length - maxDisplay;

    if (displayUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (displayUrls.length == 1)
          _buildSingleImage(context, displayUrls[0], colors)
        else
          _buildGrid(context, displayUrls, remaining, colors),
      ],
    );
  }

  Widget _buildSingleImage(
    BuildContext context,
    String url,
    MobileColors colors,
  ) {
    final fullUrl = url.startsWith('http') ? url : AppConfig.resolveUrl(url);
    return GestureDetector(
      onTap: () {
        ImageGallery.show(context, imageUrls: imageUrls);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 300,
            maxWidth: double.infinity,
          ),
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              height: 200,
              color: colors.background,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: colors.background,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<String> urls,
    int remaining,
    MobileColors colors,
  ) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          ...urls.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ImageGallery.show(
                    context,
                    imageUrls: imageUrls,
                    initialIndex: index,
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: colors.background,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildNetworkImage(url, colors),
                  ),
                ),
              ),
            );
          }),
          if (remaining > 0)
            Container(
              width: 100,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.textTertiary.withValues(alpha: 0.2),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNetworkImage(String url, MobileColors colors) {
    final fullUrl = url.startsWith('http') ? url : AppConfig.resolveUrl(url);
    return CachedNetworkImage(
      imageUrl: fullUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: colors.background,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: colors.background,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
