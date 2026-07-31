import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/campus.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../models/scout_template.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';

/// スカウト送信ダイアログ
///
/// 団体は本文を自由に書けず、定型文を選んで送る。埋め込む値も
/// 対象学生のプロフィールと自団体のイベントからしか選べない。
///
/// 送信できた場合は `true` を返して閉じる。
class ScoutComposeDialog extends StatefulWidget {
  final UserProfile student;
  final Organization senderOrg;

  const ScoutComposeDialog({
    super.key,
    required this.student,
    required this.senderOrg,
  });

  @override
  State<ScoutComposeDialog> createState() => _ScoutComposeDialogState();
}

class _ScoutComposeDialogState extends State<ScoutComposeDialog> {
  final _firestoreService = FirestoreService();

  List<Event> _events = [];
  bool _isLoadingEvents = true;

  ScoutTemplate? _selected;
  String? _selectedTag;
  Event? _selectedEvent;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _firestoreService
          .fetchUpcomingEventsByOrganization(widget.senderOrg.id);
      if (mounted) setState(() => _events = events);
    } catch (_) {
      // イベントが取れなくても他の定型文は選べるので、無視して続行する
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  /// この学生に対して実際に使える定型文だけを返す
  List<ScoutTemplate> get _availableTemplates {
    return ScoutTemplate.all.where((t) {
      switch (t.slot) {
        case ScoutSlot.tag:
          return widget.student.interests.isNotEmpty;
        case ScoutSlot.event:
          return _events.isNotEmpty;
        case ScoutSlot.campus:
          // 「両キャンパス」の学生には文意が通らないため出さない
          return widget.student.mainCampus != Campus.both;
        case ScoutSlot.grade:
        case ScoutSlot.none:
          return true;
      }
    }).toList();
  }

  /// 定型文に埋め込む値。選択が未完了なら null
  String? get _templateArg {
    switch (_selected?.slot) {
      case ScoutSlot.tag:
        return _selectedTag;
      case ScoutSlot.event:
        return _selectedEvent?.title;
      case ScoutSlot.campus:
        // Firestore には enum 名で保存する（表示時に日本語へ変換される）
        return widget.student.mainCampus.name;
      case ScoutSlot.grade:
        return widget.student.grade.toString();
      case ScoutSlot.none:
      case null:
        return null;
    }
  }

  bool get _canSend {
    final template = _selected;
    if (template == null || _isSending) return false;
    return !template.needsArg || _templateArg != null;
  }

  Future<void> _send() async {
    final template = _selected;
    if (template == null) return;

    setState(() => _isSending = true);
    try {
      await _firestoreService.sendScout(
        targetUserId: widget.student.id,
        senderOrg: widget.senderOrg,
        template: template,
        templateArg: _templateArg,
        templateEventId: _selectedEvent?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信に失敗しました: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.student.name} さんにスカウト送信'),
      content: SizedBox(
        width: 400,
        child: _isLoadingEvents
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '送る文章を選んでください。トラブル防止のため、'
                      'スカウトは定型文のみ送信できます。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._availableTemplates.map(_buildTemplateTile),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      _buildPreview(),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context, false),
          child: const Text(
            'キャンセル',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _canSend ? _send : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('送信する'),
        ),
      ],
    );
  }

  /// 定型文1件分の選択肢。選択中はその場で値の選択UIを開く
  Widget _buildTemplateTile(ScoutTemplate template) {
    final isSelected = _selected?.id == template.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isSending
              ? null
              : () => setState(() {
                    _selected = template;
                    // 定型文を切り替えたら、前の選択値は破棄する
                    _selectedTag = null;
                    _selectedEvent = null;
                  }),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    template.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSelected && template.slot == ScoutSlot.tag) _buildTagPicker(),
        if (isSelected && template.slot == ScoutSlot.event) _buildEventPicker(),
      ],
    );
  }

  /// 学生が登録している興味タグから1つ選ぶ
  Widget _buildTagPicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'どのタグに惹かれましたか？',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.student.interests.map((tag) {
              return ChoiceChip(
                label: Text(tag),
                selected: _selectedTag == tag,
                onSelected: _isSending
                    ? null
                    : (_) => setState(() => _selectedTag = tag),
                selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: _selectedTag == tag
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 自団体の開催予定イベントから1つ選ぶ
  Widget _buildEventPicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'どのイベントに招待しますか？',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Event>(
            initialValue: _selectedEvent,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            hint: const Text('イベントを選択'),
            items: _events.map((event) {
              return DropdownMenuItem(
                value: event,
                child: Text(
                  '${event.startAt.month}/${event.startAt.day} ${event.title}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _isSending
                ? null
                : (event) => setState(() => _selectedEvent = event),
          ),
        ],
      ),
    );
  }

  /// 学生に実際に届く文面のプレビュー
  Widget _buildPreview() {
    final template = _selected!;
    final arg = _templateArg;
    final isReady = !template.needsArg || arg != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学生に届く文面',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isReady ? template.render(arg) : '上から値を選ぶと文面が表示されます',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: isReady ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontStyle: isReady ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
