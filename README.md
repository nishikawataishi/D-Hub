# D.scout (ディースカウト) 🏀

同志社大学の部活動・サークルと新入生を繋ぐ、マッチング型スカウトアプリです。

## プロジェクト概要
D.scoutは、自分にぴったりの団体を見つけたい学生と、熱意ある新入生を探している団体を繋ぐプラットフォームです。
「どのサークルに入ればいいかわからない」「自分のスキルを活かせる団体を探したい」という学生の悩みを、団体からの直接のスカウトやイベント情報を通じて解決します。

## 主な機能
- **組織検索 & フィルタリング**: カテゴリや雰囲気から自分に合う団体を検索。
- **スカウト機能**: 団体から興味を持った学生へ直接メッセージを送信。
- **イベントカレンダー**: 各団体の新歓イベントや説明会を一元管理。
- **プロフィール管理**: 自分の属性や興味を登録して、最適なマッチングを実現。

## 技術スタック
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Authentication (匿名認証・メール認証)
  - Cloud Firestore (リアルタイムデータベース)
  - Cloud Functions (バックエンドロジック)
  - Cloud Storage (画像・ロゴアップロード)
- **State Management**: Provider

## セットアップ
1. Flutterの開発環境を構築します。
2. リポジトリをクローンします。
   ```bash
   git clone https://github.com/nishikawataishi/D-scout.git
   ```
3. 依存関係をインストールします。
   ```bash
   flutter pub get
   ```
4. Firebaseの設定ファイル（`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`）を適切な位置に配置してください。
   ※セキュリティのため、これらのファイルはソース管理から除外されています。

## ライセンス
このプロジェクトのライセンスについては検討中です。

