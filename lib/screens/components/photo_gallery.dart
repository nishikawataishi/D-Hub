import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

/// With風プロフィール写真ギャラリー（閲覧用）
/// メイン写真を大きく表示し、下に3枚のサムネイルを並べる
class PhotoGallery extends StatelessWidget {
  final List<String> photoUrls;
  final String? fallbackIconUrl;
  final Widget? fallbackWidget;

  const PhotoGallery({
    super.key,
    required this.photoUrls,
    this.fallbackIconUrl,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // メイン写真（1枚目）
        GestureDetector(
          onTap: () => _openFullScreen(context, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: photoUrls[0],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppTheme.background,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.background,
                  child: const Icon(Icons.broken_image, size: 50, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),

        // サムネイル（2〜4枚目）
        if (photoUrls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final index = i + 1;
              if (index < photoUrls.length) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4,
                      right: i == 2 ? 0 : 4,
                    ),
                    child: GestureDetector(
                      onTap: () => _openFullScreen(context, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CachedNetworkImage(
                            imageUrl: photoUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppTheme.background,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.background,
                              child: const Icon(Icons.broken_image, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // 空のプレースホルダー
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4,
                      right: i == 2 ? 0 : 4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          color: AppTheme.background,
                          child: const Icon(
                            Icons.photo_outlined,
                            color: AppTheme.border,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }),
          ),
        ],
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 全画面表示ギャラリー（PageViewでスワイプ閲覧）
class _FullScreenGallery extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenGallery({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.photoUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.photoUrls[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
