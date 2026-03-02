import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_profile.dart';
import '../models/campus.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// プロフィール編集画面
class ProfileEditScreen extends StatefulWidget {
  final UserProfile profile;

  const ProfileEditScreen({super.key, required this.profile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  late TextEditingController _nameController;
  late TextEditingController _facultyController;
  late int _selectedGrade;
  late Campus _selectedCampus;

  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _iconUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile.name == '未設定' ? '' : widget.profile.name,
    );
    _facultyController = TextEditingController(
      text: widget.profile.faculty == '未設定' ? '' : widget.profile.faculty,
    );
    _selectedGrade = widget.profile.grade;
    _selectedCampus = widget.profile.mainCampus;
    _iconUrl = widget.profile.iconUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _firestoreService.updateUserProfile(widget.profile.id, {
        'name': _nameController.text.trim(),
        'faculty': _facultyController.text.trim(),
        'grade': _selectedGrade,
        'mainCampus': _selectedCampus.name,
        if (_iconUrl != null) 'iconUrl': _iconUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted || pickedFile == null) return;

      late XFile finalFile;

      if (kIsWeb) {
        finalFile = pickedFile;
      } else {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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

        if (croppedFile == null) return;
        finalFile = XFile(croppedFile.path);
      }

      setState(() => _isUploadingImage = true);

      final url = await StorageService().uploadUserIcon(
        userId: widget.profile.id,
        file: finalFile,
      );

      if (url != null) {
        setState(() => _iconUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('アイコン画像をアップロードしました'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター変更（UIのみ）
              Center(
                child: _isUploadingImage
                    ? const CircularProgressIndicator()
                    : Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              shape: BoxShape.circle,
                              image: _iconUrl != null
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        _iconUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _iconUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              const Text(
                '基本情報',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // 名前
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前（フルネーム）',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 学部
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(
                  labelText: '学部',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '学部を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 回生（学年）
              DropdownButtonFormField<int>(
                initialValue: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: '回生',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4, 5, 6].map((grade) {
                  return DropdownMenuItem(
                    value: grade,
                    child: Text('$grade回生'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGrade = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 主なキャンパス
              DropdownButtonFormField<Campus>(
                initialValue: _selectedCampus,
                decoration: const InputDecoration(
                  labelText: 'メインキャンパス',
                  border: OutlineInputBorder(),
                ),
                items: Campus.values.map((campus) {
                  return DropdownMenuItem(
                    value: campus,
                    child: Text(campus.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCampus = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
