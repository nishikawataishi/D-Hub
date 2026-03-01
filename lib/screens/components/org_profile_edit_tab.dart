import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class OrgProfileEditTab extends StatefulWidget {
  const OrgProfileEditTab({super.key});

  @override
  State<OrgProfileEditTab> createState() => _OrgProfileEditTabState();
}

class _OrgProfileEditTabState extends State<OrgProfileEditTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _instaController;

  Organization? _org;
  bool _isLoading = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _instaController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final org = await FirestoreService().getOrganization(user.uid);
      if (org != null) {
        setState(() {
          _org = org;
          _nameController.text = org.name;
          _descController.text = org.description;
          _instaController.text = org.instagramUrl;
          _isLoading = false;
        });
        return;
      }
    }
    // 空あるいはエラーの場合はローディング終了
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _instaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _isUploadingImage
                  ? const CircularProgressIndicator()
                  : Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          backgroundImage: _org?.logoUrl != null
                              ? CachedNetworkImageProvider(_org!.logoUrl!)
                              : null,
                          child: _org?.logoUrl == null
                              ? Text(
                                  _org?.logoEmoji ?? '🎨',
                                  style: const TextStyle(fontSize: 40),
                                )
                              : null,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _pickAndUploadImage,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('基本情報'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: '団体名',
              icon: Icons.group,
              validator: (v) => v!.isEmpty ? '団体名を入力してください' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descController,
              label: '紹介文',
              icon: Icons.description,
              maxLines: 5,
              validator: (v) => v!.isEmpty ? '紹介文を入力してください' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _instaController,
              label: 'Instagramリンク',
              icon: Icons.link,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存する',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.surface,
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // Crop image
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
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 400, height: 400),
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() => _isUploadingImage = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _org != null) {
        final url = await StorageService().uploadOrgImage(
          orgId: user.uid,
          file: XFile(croppedFile.path),
          isLogo: true,
        );

        if (url != null) {
          final updatedOrg = Organization(
            id: _org!.id,
            name: _org!.name,
            description: _org!.description,
            category: _org!.category,
            campus: _org!.campus,
            logoEmoji: _org!.logoEmoji,
            instagramUrl: _org!.instagramUrl,
            logoUrl: url,
          );

          await FirestoreService().saveOrganization(updatedOrg);

          if (mounted) {
            setState(() {
              _org = updatedOrg;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ロゴ画像を更新しました'),
                backgroundColor: AppTheme.success,
              ),
            );
          }
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

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _org == null) return;

      final updatedOrg = Organization(
        id: user.uid,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        category: _org!.category, // カテゴリやキャンパスは今回はそのまま（必要なら後でフォーム追加）
        campus: _org!.campus,
        logoEmoji: _org!.logoEmoji,
        instagramUrl: _instaController.text.trim(),
        logoUrl: _org!.logoUrl,
      );

      try {
        await FirestoreService().saveOrganization(updatedOrg);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィールを保存しました'),
            backgroundColor: AppTheme.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィールの保存に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
