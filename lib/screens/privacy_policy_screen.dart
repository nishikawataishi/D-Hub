import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// プライバシーポリシー画面
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          _privacyPolicyText,
          style: TextStyle(
            fontSize: 14,
            height: 1.8,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

const String _privacyPolicyText = '''D.scout プライバシーポリシー

最終更新日：2026年3月20日

D.scout（以下「本サービス」）は、ユーザーの個人情報の保護を重要と考え、以下のとおりプライバシーポリシーを定めます。

1. 取得する情報
本サービスでは、以下の情報を取得します。

(1) ユーザーが提供する情報
・メールアドレス（大学メールアドレスを含む）
・氏名、学部、学年、キャンパス
・プロフィール写真
・興味・関心タグ
・団体情報（団体アカウントの場合：団体名、説明、活動場所等）

(2) 自動的に取得する情報
・アプリの利用状況（Firebase Analyticsによる匿名の利用統計）
・端末情報（OS、バージョン等）
・クラッシュレポート（Firebase Crashlytics）

2. 情報の利用目的
取得した情報は、以下の目的で利用します。
・本サービスの提供・運営・改善
・ユーザー認証（学生認証を含む）
・団体とユーザーのマッチング機能の提供
・お問い合わせ対応
・利用状況の分析によるサービス改善
・重要なお知らせの通知

3. 情報の第三者提供
ユーザーの個人情報は、以下の場合を除き、第三者に提供しません。
・ユーザーの同意がある場合
・法令に基づく場合
・人の生命・身体・財産の保護に必要な場合

4. 外部サービスの利用
本サービスでは、以下の外部サービスを利用しています。

(1) Firebase（Google LLC）
・Firebase Authentication：ユーザー認証
・Cloud Firestore：データの保存
・Firebase Storage：画像ファイルの保存
・Firebase Analytics：利用状況の匿名分析
・Firebase Crashlytics：アプリのクラッシュ情報収集

これらのサービスにおける情報の取り扱いについては、Google のプライバシーポリシー（https://policies.google.com/privacy）をご確認ください。

5. 情報の管理
・取得した個人情報は、適切な安全管理措置を講じて保護します。
・不正アクセス、紛失、破壊、改ざん、漏洩の防止に努めます。

6. ユーザーの権利
ユーザーは、以下の権利を有します。
・自己の個人情報の開示を請求する権利
・個人情報の訂正・削除を請求する権利
・アカウントの削除（退会）を行う権利

7. Cookie・トラッキング技術
本サービスのモバイルアプリでは、Cookieは使用しません。Firebase Analyticsによる匿名の利用統計データの収集を行います。

8. 未成年者の利用
本サービスは大学生を対象としていますが、18歳未満の方が利用する場合は保護者の同意を得た上でご利用ください。

9. プライバシーポリシーの変更
本ポリシーの内容は、法令の変更やサービスの変更に伴い、予告なく変更することがあります。変更後のプライバシーポリシーは、アプリ内に掲載した時点から効力を生じるものとします。

10. お問い合わせ
個人情報の取り扱いに関するお問い合わせは、アプリ内の「ヘルプ・お問い合わせ」よりご連絡ください。

以上''';
