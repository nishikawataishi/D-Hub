import 'package:flutter/material.dart';
import '../models/account_role.dart';
import '../models/blocked_account.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// ブロックしたアカウントの一覧と解除を行う画面。
///
/// 学生（ブロックした団体）と団体（ブロックした学生）で共用する。
class BlockedAccountsScreen extends StatefulWidget {
  /// この画面を開いている側の立場
  final AccountRole role;

  const BlockedAccountsScreen({super.key, required this.role});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  final _firestoreService = FirestoreService();
  final _unblocking = <String>{};

  Future<void> _unblock(BlockedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブロックの解除'),
        content: Text(
          widget.role == AccountRole.student
              ? '${account.name}のブロックを解除すると、'
                  'この団体からのスカウトが再び届くようになります。'
              : '${account.name}のブロックを解除すると、'
                  'この学生が再び学生一覧に表示されます。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _unblocking.add(account.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.unblockAccount(
        as: widget.role,
        targetId: account.id,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${account.name}のブロックを解除しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ブロックの解除に失敗しました: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _unblocking.remove(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.role.counterpartLabel;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('ブロックした$label')),
      body: StreamBuilder<List<BlockedAccount>>(
        stream: _firestoreService.getBlockedAccounts(widget.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ブロック一覧の取得に失敗しました\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            );
          }

          final accounts = snapshot.data ?? const <BlockedAccount>[];
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ブロックした$labelはいません',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final busy = _unblocking.contains(account.id);
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: AppTheme.textSecondary,
                  ),
                  title: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: account.blockedAt != null
                      ? Text(
                          '${account.blockedAt!.year}/'
                          '${account.blockedAt!.month}/'
                          '${account.blockedAt!.day} にブロック',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        )
                      : null,
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _unblock(account),
                          child: const Text('解除'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
