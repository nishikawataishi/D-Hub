import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

/// プロフィール写真編集ウィジェット（2x2グリッド、最大4枚）
class PhotoGalleryEditor extends StatelessWidget {
  final List<String> photoUrls;
  final Set<int> uploadingIndices;
  final ValueChanged<int> onAddPhoto;
  final ValueChanged<int> onRemovePhoto;

  const PhotoGalleryEditor({
    super.key,
    required this.photoUrls,
    this.uploadingIndices = const {},
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'プロフィール写真',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '最大4枚まで追加できます。1枚目がメイン写真になります。',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final hasPhoto = index < photoUrls.length;
            final isUploading = uploadingIndices.contains(index);

            return GestureDetector(
              onTap: isUploading
                  ? null
                  : hasPhoto
                      ? null
                      : () => onAddPhoto(index),
              onLongPress: hasPhoto && !isUploading
                  ? () => _confirmRemove(context, index)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto ? Colors.transparent : AppTheme.border,
                    width: hasPhoto ? 0 : 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto)
                      CachedNetworkImage(
                        imageUrl: photoUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: AppTheme.textSecondary),
                        ),
                      )
                    else if (isUploading)
                      const Center(child: CircularProgressIndicator())
                    else
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: AppTheme.textSecondary),
                            SizedBox(height: 4),
                            Text(
                              '追加',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // メイン写真バッジ（1枚目）
                    if (index == 0 && hasPhoto)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'メイン',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // 削除ボタン
                    if (hasPhoto && !isUploading)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _confirmRemove(context, index),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(127),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // ローディングオーバーレイ
                    if (isUploading && hasPhoto)
                      Container(
                        color: Colors.black.withAlpha(100),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _confirmRemove(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真を削除'),
        content: const Text('この写真を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRemovePhoto(index);
            },
            child: const Text('削除', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
