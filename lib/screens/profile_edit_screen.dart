import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/campus.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'components/photo_gallery_editor.dart';

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
  late List<String> _photoUrls;
  final Set<int> _uploadingPhotoIndices = {};

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
    _photoUrls = List<String>.from(widget.profile.photoUrls);
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
        'photoUrls': _photoUrls,
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
      setState(() => _isUploadingImage = true);

      // ImageService を使用して画像を選択・加工
      final finalFile = await ImageService().pickAndProcessImage();
      if (!mounted || finalFile == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

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

  Future<void> _pickAndUploadPhoto(int index) async {
    try {
      setState(() => _uploadingPhotoIndices.add(index));

      final finalFile = await ImageService().pickAndProcessImage(
        maxWidth: 1024,
        maxHeight: 1024,
        aspectRatio: null,
        crop: false,
      );
      if (!mounted || finalFile == null) {
        setState(() => _uploadingPhotoIndices.remove(index));
        return;
      }

      final url = await StorageService().uploadUserPhoto(
        userId: widget.profile.id,
        file: finalFile,
      );

      if (url != null && mounted) {
        setState(() {
          if (index < _photoUrls.length) {
            _photoUrls[index] = url;
          } else {
            _photoUrls.add(url);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('写真のアップロードに失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhotoIndices.remove(index));
    }
  }

  void _removePhoto(int index) {
    if (index < _photoUrls.length) {
      setState(() => _photoUrls.removeAt(index));
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
              const SizedBox(height: 24),

              // 公開範囲の説明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'プロフィール情報（名前・学部・写真・タグなど）は、審査承認済みのサークル・部活・ゼミ等の団体に公開されます。他の学生には公開されません。',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // プロフィール写真ギャラリー編集
              PhotoGalleryEditor(
                photoUrls: _photoUrls,
                uploadingIndices: _uploadingPhotoIndices,
                onAddPhoto: _pickAndUploadPhoto,
                onRemovePhoto: _removePhoto,
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
