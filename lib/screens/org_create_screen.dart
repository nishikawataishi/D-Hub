import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Added for XFile
import '../services/image_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../models/organization.dart';
import '../models/campus.dart';
import '../theme/app_theme.dart';

class OrgCreateScreen extends StatefulWidget {
  const OrgCreateScreen({super.key});

  @override
  State<OrgCreateScreen> createState() => _OrgCreateScreenState();
}

class _OrgCreateScreenState extends State<OrgCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instaController = TextEditingController();

  final List<OrgCategory> _selectedCategories = [];
  final Campus _selectedCampus = Campus.both;
  File? _proofImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _instaController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final xFile = await ImageService().pickAndProcessImage();
    if (xFile != null) {
      setState(() => _proofImage = File(xFile.path));
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proofImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('活動実態の証明画像をアップロードしてください')));
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('カテゴリーを1つ以上選択してください')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ログインが必要です');

      // 1. 証明画像のアップロード
      final proofImageUrl = await StorageService().uploadOrgImage(
        orgId: user.uid,
        file: _proofImage!,
        isLogo: false, // 証明画像用
      );

      if (proofImageUrl == null) throw Exception('画像のアップロードに失敗しました');

      // 2. 団体データの作成
      final newOrg = Organization(
        id: user.uid, // 代表者のUIDをドキュメントIDとして使用（1人1団体制限のため）
        name: _nameController.text.trim(),
        description: '審査後にプロフィールを編集できます。',
        categories: _selectedCategories,
        campus: _selectedCampus,
        logoEmoji: '🎨',
        instagramUrl: _instaController.text.trim(),
        representativeId: user.uid,
        status: 'pending',
        proofImageUrl: proofImageUrl,
        createdAt: DateTime.now(),
      );

      await FirestoreService().saveOrganization(newOrg);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('申請完了'),
            content: const Text('団体作成の申請を受け付けました。運営による審査をお待ちください（通常24時間以内）。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  Navigator.of(context).pop(); // 作成画面を閉じる（マイページへ戻る）
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('申請に失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('団体を作成する'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'なりすまし防止のため、運営が手動で審査を行います。承認まで最大24時間かかる場合があります。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
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
                controller: _instaController,
                label: 'Instagram URL',
                icon: Icons.link,
                validator: (v) {
                  if (v!.isEmpty) return 'Instagram URLを入力してください';
                  if (!v.contains('instagram.com')) return '正しいURLを入力してください';
                  return null;
                },
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
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('活動証明画像'),
              const SizedBox(height: 8),
              const Text(
                '新歓チラシ、部室の写真、またはインスタのプロフィール編集画面のスクショなど、活動実態がわかる画像を添付してください。',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickProofImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: _proofImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_proofImage!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 48,
                              color: AppTheme.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '画像をアップロード',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '申請する',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surface,
      ),
    );
  }
}
