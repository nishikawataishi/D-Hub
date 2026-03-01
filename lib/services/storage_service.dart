import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage へのアップロード処理を扱うサービス
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// 団体用ロゴや活動写真をアップロードする
  /// Web環境(kIsWeb)とモバイル環境を両方サポート
  Future<String?> uploadOrgImage({
    required String orgId,
    required XFile file,
    bool isLogo = true,
  }) async {
    try {
      final folder = isLogo ? 'logo' : 'photos';
      final fileName = '${_uuid.v4()}_${file.name}';
      final ref = _storage.ref().child(
        'organizations/$orgId/$folder/$fileName',
      );

      if (kIsWeb) {
        // Web用のアップロード (Bytesを使用)
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
        );
        await ref.putData(bytes, metadata);
      } else {
        // モバイル・デスクトップ用のアップロード
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
        );
        await ref.putFile(File(file.path), metadata);
      }

      // 成功したらダウンロードURLを返す
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading org image: $e');
      return null;
    }
  }

  /// ユーザーアイコンをアップロードする
  Future<String?> uploadUserIcon({
    required String userId,
    required XFile file,
  }) async {
    try {
      final fileName = '${_uuid.v4()}_${file.name}';
      final ref = _storage.ref().child('users/$userId/icon/$fileName');

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
        );
        await ref.putData(bytes, metadata);
      } else {
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
        );
        await ref.putFile(File(file.path), metadata);
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading user icon: $e');
      return null;
    }
  }
}
