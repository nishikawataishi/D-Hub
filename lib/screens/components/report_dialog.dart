import 'package:flutter/material.dart';
import '../../models/account_role.dart';
import '../../models/report.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// 通報ダイアログを表示する。通報が送信された場合のみ true を返す。
///
/// [contentSnapshot] は通報時点の対象コンテンツ。利用規約 第7条2に基づき、
/// 通報するとこの内容が運営に共有されることをダイアログ上でも明示する。
Future<bool> showReportDialog(
  BuildContext context, {
  required AccountRole reporterRole,
  required ReportTargetType targetType,
  required String targetId,
  required String targetName,
  Map<String, dynamic> contentSnapshot = const {},
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ReportDialog(
      reporterRole: reporterRole,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      contentSnapshot: contentSnapshot,
    ),
  );
  return submitted == true;
}

class _ReportDialog extends StatefulWidget {
  final AccountRole reporterRole;
  final ReportTargetType targetType;
  final String targetId;
  final String targetName;
  final Map<String, dynamic> contentSnapshot;

  const _ReportDialog({
    required this.reporterRole,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.contentSnapshot,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _detailController = TextEditingController();
  ReportReason? _reason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirestoreService().submitReport(
        reporterRole: widget.reporterRole,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetName: widget.targetName,
        reason: reason,
        detail: _detailController.text,
        snapshot: widget.contentSnapshot,
      );
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('通報を受け付けました。運営が内容を確認します。'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('通報の送信に失敗しました: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.targetName}を通報'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 規約 第7条2・4 の内容を通報前に明示する
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '通報すると、対象の登録内容が運営に共有され、運営が確認します。\n'
                  '通報したことや、誰が通報したかは相手に通知されません。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '通報の理由',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...ReportReason.values.map(_buildReasonTile),
              const SizedBox(height: 16),
              const Text(
                '補足（任意）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailController,
                maxLines: 3,
                maxLength: 500,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: '具体的な状況があればご記入ください',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: (_reason == null || _isSubmitting) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('通報する'),
        ),
      ],
    );
  }

  Widget _buildReasonTile(ReportReason reason) {
    final selected = _reason == reason;
    return InkWell(
      onTap: _isSubmitting ? null : () => setState(() => _reason = reason),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason.label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
