import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../models/campus.dart';
import '../models/organization.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// イベント作成・編集画面
class EventEditScreen extends StatefulWidget {
  final Event? event;

  const EventEditScreen({super.key, this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _feeController;
  late TextEditingController _capacityController;
  late TextEditingController _locationController;
  late TextEditingController _groupLineUrlController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Campus _selectedCampus = Campus.both;
  bool _isLoading = false;
  Organization? _currentOrg;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _feeController = TextEditingController(text: widget.event?.fee ?? '');
    _capacityController = TextEditingController(text: widget.event?.capacity ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _groupLineUrlController = TextEditingController(text: widget.event?.groupLineUrl ?? '');

    if (widget.event != null) {
      _selectedDate = widget.event!.startAt;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.startAt);
      _selectedCampus = widget.event!.campus;
      _currentOrg = widget.event!.organization;
    } else {
      _loadCurrentOrg();
    }
  }

  Future<void> _loadCurrentOrg() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final org = await _firestoreService.getOrganization(user.uid);
      if (mounted) {
        setState(() {
          _currentOrg = org;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _groupLineUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // 過去の日付は制限
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日時を設定してください')));
      return;
    }

    if (_currentOrg == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('団体情報が取得できませんでした')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final fee = _feeController.text.trim().isEmpty ? null : _feeController.text.trim();
      final capacity = _capacityController.text.trim().isEmpty ? null : _capacityController.text.trim();
      final location = _locationController.text.trim().isEmpty ? null : _locationController.text.trim();
      final groupLineUrl = _groupLineUrlController.text.trim().isEmpty ? null : _groupLineUrlController.text.trim();

      if (widget.event == null) {
        // 新規作成
        final newEvent = Event(
          id: '', // Firestore側で自動生成される
          organization: _currentOrg!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startAt: startAt,
          campus: _selectedCampus,
          organizationLogoUrl: _currentOrg!.logoUrl,
          fee: fee,
          capacity: capacity,
          location: location,
          groupLineUrl: groupLineUrl,
        );
        await _firestoreService.createEvent(newEvent);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('イベントを作成しました')));
          Navigator.pop(context);
        }
      } else {
        // 更新
        final updatedEvent = widget.event!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startAt: startAt,
          campus: _selectedCampus,
          organizationLogoUrl: _currentOrg?.logoUrl,
          fee: fee,
          capacity: capacity,
          location: location,
          groupLineUrl: groupLineUrl,
        );
        await _firestoreService.updateEvent(updatedEvent);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('イベントを更新しました')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEditing ? 'イベントを編集' : '新規イベント作成'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('イベントの削除'),
                    content: const Text('このイベントを削除してよろしいですか？\n削除すると元に戻せません。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          '削除する',
                          style: TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  setState(() => _isLoading = true);
                  try {
                    await _firestoreService.deleteEvent(widget.event!.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('イベントを削除しました')),
                      );
                      Navigator.pop(context); // 一覧画面に戻る
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
                      setState(() => _isLoading = false);
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'イベントタイトル',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '例: 新歓バスケ体験会',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'タイトルを入力してください';
                        }
                        if (value.trim().length > 100) {
                          return '100文字以内で入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'イベント詳細',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'イベントの内容、持ち物、参加条件などを入力してください',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '詳細を入力してください';
                        }
                        if (value.trim().length > 2000) {
                          return '2000文字以内で入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '開催日',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedDate == null
                                            ? '日付を選択'
                                            : '${_selectedDate!.year}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: _selectedDate == null
                                              ? AppTheme.textSecondary
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '開始時間',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime == null
                                            ? '時間を選択'
                                            : _selectedTime!.format(context),
                                        style: TextStyle(
                                          color: _selectedTime == null
                                              ? AppTheme.textSecondary
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.access_time,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'イベント情報',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoField(
                      controller: _locationController,
                      icon: Icons.place_outlined,
                      label: '場所',
                      hint: '例: 今出川キャンパス 第1体育館',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoField(
                            controller: _feeController,
                            icon: Icons.payments_outlined,
                            label: '参加費',
                            hint: '例: 無料、500円',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoField(
                            controller: _capacityController,
                            icon: Icons.people_outline,
                            label: '人数',
                            hint: '例: 先着20名',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoField(
                      controller: _groupLineUrlController,
                      icon: Icons.chat_bubble_outline,
                      label: 'グループLINE URL（承認後に表示）',
                      hint: '例: https://line.me/ti/g2/xxxx',
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      '開催キャンパス',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Campus>(
                          value: _selectedCampus,
                          isExpanded: true,
                          items: Campus.values.map((Campus campus) {
                            return DropdownMenuItem<Campus>(
                              value: campus,
                              child: Text(campus.label),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCampus = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isEditing ? '更新する' : '作成する',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
