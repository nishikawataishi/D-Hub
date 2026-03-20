import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/image_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/organization.dart';
import '../../models/campus.dart';
import '../../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'photo_gallery_editor.dart';

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
  late TextEditingController _lineController;

  Organization? _org;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  List<OrgCategory> _selectedCategories = [];
  Campus _selectedCampus = Campus.both;
  List<String> _photoUrls = [];
  final Set<int> _uploadingPhotoIndices = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _instaController = TextEditingController();
    _lineController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final org = await FirestoreService().getOrganization(user.uid);
        if (org != null) {
          if (mounted) {
            setState(() {
              _org = org;
              _nameController.text = org.name;
              _descController.text = org.description;
              _instaController.text = org.instagramUrl;
              _lineController.text = org.groupLineUrl;
              _selectedCategories = List.from(org.categories);
              _selectedCampus = org.campus;
              _photoUrls = List<String>.from(org.photoUrls);
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('OrgProfileEditTab._loadProfile error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _instaController.dispose();
    _lineController.dispose();
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
            const SizedBox(height: 24),
            // プロフィール写真ギャラリー編集
            PhotoGalleryEditor(
              photoUrls: _photoUrls,
              uploadingIndices: _uploadingPhotoIndices,
              onAddPhoto: _pickAndUploadPhoto,
              onRemovePhoto: _removePhoto,
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
            const SizedBox(height: 16),
            _buildTextField(
              controller: _lineController,
              label: 'グループLINE URL',
              icon: Icons.chat_bubble_outline,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('カテゴリー（複数選択可）'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrgCategory.values
                  .where((c) => c != OrgCategory.all)
                  .map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('活動キャンパス'),
            const SizedBox(height: 12),
            DropdownButtonFormField<Campus>(
              initialValue: _selectedCampus,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: AppTheme.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: Campus.values.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.label));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCampus = v);
              },
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

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final url = await StorageService().uploadOrgPhoto(
        orgId: user.uid,
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

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploadingImage = true);

      // ImageService を使用して画像を選択・加工
      final finalFile = await ImageService().pickAndProcessImage();
      if (!mounted || finalFile == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _org != null) {
        final url = await StorageService().uploadOrgImage(
          orgId: user.uid,
          file: finalFile,
          isLogo: true,
        );

        if (url != null) {
          final updatedOrg = Organization(
            id: _org!.id,
            name: _org!.name,
            description: _org!.description,
            categories: _selectedCategories.isNotEmpty
                ? _selectedCategories
                : _org!.categories,
            campus: _selectedCampus,
            logoEmoji: _org!.logoEmoji,
            instagramUrl: _org!.instagramUrl,
            groupLineUrl: _org!.groupLineUrl,
            logoUrl: url,
            photoUrls: _photoUrls,
            status: _org!.status,
            representativeId: _org!.representativeId,
            proofImageUrl: _org!.proofImageUrl,
            verifiedAt: _org!.verifiedAt,
            isOfficial: _org!.isOfficial,
          );
          await FirestoreService().updateOrgProfile(updatedOrg);
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
            content: Text('アップロードに失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
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
        categories: _selectedCategories.isNotEmpty
            ? _selectedCategories
            : [OrgCategory.culture],
        campus: _selectedCampus,
        logoEmoji: _org!.logoEmoji,
        instagramUrl: _instaController.text.trim(),
        groupLineUrl: _lineController.text.trim(),
        logoUrl: _org!.logoUrl,
        photoUrls: _photoUrls,
        status: _org!.status,
        representativeId: _org!.representativeId,
        proofImageUrl: _org!.proofImageUrl,
        verifiedAt: _org!.verifiedAt,
        isOfficial: _org!.isOfficial,
      );

      try {
        await FirestoreService().updateOrgProfile(updatedOrg);
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
