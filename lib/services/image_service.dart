import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 画像の選択・加工（トリミング・圧縮）を統合的に扱うサービス
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// ギャラリーから画像を選択し、必要に応じてトリミング・圧縮を行う
  /// [maxWidth], [maxHeight], [imageQuality] はデフォルト値を設定
  Future<XFile?> pickAndProcessImage({
    double maxWidth = 512,
    double maxHeight = 512,
    int imageQuality = 80,
    bool crop = true,
    CropAspectRatio? aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1),
  }) async {
    try {
      // 1. 画像の選択
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      // 2. トリミング (Webの場合はスキップ、または crop が false の場合もスキップ)
      if (kIsWeb || !crop) {
        return pickedFile;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '画像のトリミング',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: '画像のトリミング', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (e) {
      debugPrint('Error picking/processing image: $e');
      return null;
    }
  }
}
