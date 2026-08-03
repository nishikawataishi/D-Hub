import 'package:flutter/material.dart';
import '../../models/account_role.dart';
import '../../models/report.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'report_dialog.dart';

/// 詳細画面のAppBarに置く通報・ブロックメニュー。
///
/// 学生から団体へ、団体から学生へのどちらにも使う。表示する相手の種別は
/// [viewerRole] から決まる（D-Hubの通報・ブロックは常に学生↔団体のため）。
class ModerationMenu extends StatefulWidget {
  /// このメニューを操作する側の立場
  final AccountRole viewerRole;

  /// 相手のUID
  final String targetId;

  /// 相手の表示名
  final String targetName;

  /// 通報時に運営へ共有する対象コンテンツ（利用規約 第7条2）
  final Map<String, dynamic> contentSnapshot;

  /// ブロックが完了したときの処理。詳細画面を閉じる用途を想定
  final VoidCallback? onBlocked;

  const ModerationMenu({
    super.key,
    required this.viewerRole,
    required this.targetId,
    required this.targetName,
    this.contentSnapshot = const {},
    this.onBlocked,
  });

  @override
  State<ModerationMenu> createState() => _ModerationMenuState();
}

class _ModerationMenuState extends State<ModerationMenu> {
  final _firestoreService = FirestoreService();
  bool _isBlocked = false;
  bool _isBusy = false;

  /// 相手の種別。学生が見ているなら相手は団体、団体が見ているなら相手は学生
  ReportTargetType get _targetType => widget.viewerRole == AccountRole.student
      ? ReportTargetType.organization
      : ReportTargetType.user;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    final blocked = await _firestoreService.isBlocked(
      as: widget.viewerRole,
      targetId: widget.targetId,
    );
    if (mounted) setState(() => _isBlocked = blocked);
  }

  Future<void> _report() async {
    await showReportDialog(
      context,
      reporterRole: widget.viewerRole,
      targetType: _targetType,
      targetId: widget.targetId,
      targetName: widget.targetName,
      contentSnapshot: widget.contentSnapshot,
    );
  }

  Future<void> _block() async {
    final isStudent = widget.viewerRole == AccountRole.student;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.targetName}をブロック'),
        content: Text(
          isStudent
              ? 'ブロックすると、この団体からスカウトが届かなくなり、'
                  '団体一覧にも表示されなくなります。\n\n'
                  'ブロックしたことは相手に通知されません。'
                  'ブロックはいつでも解除できます。'
              : 'ブロックすると、この学生は学生一覧に表示されなくなります。\n\n'
                  'ブロックしたことは相手に通知されません。'
                  'ブロックはいつでも解除できます。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ブロックする',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.blockAccount(
        as: widget.viewerRole,
        targetId: widget.targetId,
        targetName: widget.targetName,
      );
      if (!mounted) return;
      setState(() {
        _isBlocked = true;
        _isBusy = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('${widget.targetName}をブロックしました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onBlocked?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('ブロックに失敗しました: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _unblock() async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.unblockAccount(
        as: widget.viewerRole,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      setState(() {
        _isBlocked = false;
        _isBusy = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('${widget.targetName}のブロックを解除しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('ブロックの解除に失敗しました: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !_isBusy,
      icon: const Icon(Icons.more_vert),
      tooltip: 'その他',
      onSelected: (value) {
        switch (value) {
          case 'report':
            _report();
          case 'block':
            _block();
          case 'unblock':
            _unblock();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined, size: 20),
            title: Text('通報する'),
          ),
        ),
        PopupMenuItem(
          value: _isBlocked ? 'unblock' : 'block',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _isBlocked ? Icons.lock_open_outlined : Icons.block,
              size: 20,
              color: _isBlocked ? null : AppTheme.error,
            ),
            title: Text(
              _isBlocked ? 'ブロックを解除する' : 'ブロックする',
              style: TextStyle(color: _isBlocked ? null : AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
