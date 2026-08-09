# D-Hub（ディーハブ）

[![CI](https://github.com/nishikawataishi/D-Hub/actions/workflows/ci.yml/badge.svg)](https://github.com/nishikawataishi/D-Hub/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)](https://firebase.google.com/)

**同志社大学・同志社女子大学の学生と学内団体（サークル・ゼミ）をつなぐ、スカウト型マッチングプラットフォーム。**

学生が団体を探すのではなく、**団体から学生へ声がかかる**逆求人型のアプローチを採用しています。「選ぶ疲れ」を「選ばれる喜び」に変えることを目指したサービスです。

- 🌐 アプリ: https://d-hub-link.com
- 📄 サービス紹介: https://www.d-hub-link.com

> 個人開発（企画・要件定義・設計・実装・テスト・デプロイ・運用をすべて一人で担当）

<!-- TODO: スクリーンショットを3枚ほど（ホーム / スカウト / イベント） -->

---

## 解決する課題

| 立場 | 課題 | D-Hub のアプローチ |
| :--- | :--- | :--- |
| **学生** | 数多のサークル・ゼミから自分に合うものを探すのは負担が大きい | プロフィールを登録しておけば、団体側から興味に基づいたスカウトが届く |
| **団体** | 興味を持ちそうな学生に届く手段が、SNSとビラしかない | 学年・キャンパス・興味タグで学生を検索し、直接アプローチできる |
| **双方** | 学外の不審なアカウント、実体のない団体が混ざるリスク | 大学メールによる在籍確認と、運営による団体審査で閉じた空間を維持 |

---

## 主な機能

### 学生向け
- **2層認証** — アカウント登録（メール／パスワード）に加え、大学メールアドレスへの確認コードで在籍を確認
- **団体検索** — インクリメンタル検索とジャンルフィルタによる一覧表示
- **スカウト受信** — 団体からの勧誘を受け取り、興味があれば Instagram・LINE で直接つながる
- **イベント参加** — 学内イベントの閲覧・参加申請・カレンダー登録（キャンパス別のカラーラベル付き）
- **プロフィール管理** — 学部・学年・キャンパス・興味タグ・写真ギャラリー
- **ブロック / 通報** — 特定の団体からのスカウトを遮断、不適切な相手を運営に通報

### 団体向け
- **学生検索とスカウト送信** — 条件で学生を探し、**5種類の定型文**から選んで送信
- **イベント作成・参加者管理** — イベントの公開と、参加申請の承認／却下
- **団体プロフィール** — 活動内容、写真、Instagram・LINE への導線

### 運営向け
- **団体審査** — 申請された団体を承認／却下（承認されるまでスカウトもイベント作成もできない）
- **通報対応・ユーザー管理・問い合わせ管理**

<!-- TODO: 各機能の画面キャプチャや補足を追記 -->

---

## 技術スタック

| レイヤー | 技術 | 採用理由 |
| :--- | :--- | :--- |
| **フロントエンド** | Flutter 3.41.2 / Dart SDK ^3.11.0 | 1つのコードベースで Web・iOS・Android に対応。個人開発の工数制約下で複数プラットフォームを扱うため |
| **状態管理** | provider 6.1.5 | 認証状態の管理が中心の構成に対して、ChangeNotifier + Consumer で必要十分 |
| **モデル層** | freezed 3.1 / json_serializable | イミュータブルなデータクラスと JSON 変換を自動生成し、ボイラープレートを排除 |
| **認証** | Firebase Authentication | メール／パスワード認証、Custom Claims による権限管理 |
| **データベース** | Cloud Firestore | リアルタイム同期、セキュリティルールによるサーバーサイド権限制御 |
| **サーバーレス** | Cloud Functions Gen2 (Node.js 22) | 確認コードの生成・ハッシュ化・検証など、クライアントに置けない処理を実行 |
| **ストレージ** | Cloud Storage for Firebase | アイコン・団体写真・ギャラリー画像 |
| **メール送信** | Nodemailer | Cloud Functions 経由での確認コード配信 |
| **ホスティング** | Firebase Hosting | マルチサイト構成（アプリ本体 + 紹介ページ） |
| **DNS** | Cloudflare | カスタムドメイン管理 |
| **CI** | GitHub Actions | 7ジョブ構成（後述） |

> 本番環境で稼働しているのは Flutter Web ビルドです。iOS・Android は CI 上でビルド検証を行っており、ストア申請を準備中です。

---

## アーキテクチャ

```
                        Flutter (Web / iOS / Android)
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                      ▼
     Firebase Auth          Cloud Firestore          Cloud Storage
   ・メール/パスワード認証     ・7コレクション            ・画像のみ / 5MB以下
   ・Custom Claims で権限     ・セキュリティルール316行    ・所有者のみ書き込み
                                     ▲
                                     │ Admin SDK
                              Cloud Functions Gen2
                        ・確認コードの生成・ハッシュ化・検証
                        ・管理者権限の付与／剥奪
                        ・退会時のデータ一括削除
```

**Firestore のコレクション構成**

| コレクション | 役割 |
| :--- | :--- |
| `users` | 学生プロフィール（+ `private` に認証メタデータ、`blocks` にブロック情報） |
| `organizations` | 団体情報と審査ステータス（+ `blocks`） |
| `events` | イベント（+ `applications` サブコレクションで参加申請） |
| `scouts` | 団体から学生へのスカウト |
| `reports` | 通報 |
| `contacts` | 問い合わせ |
| `tags` | 興味タグのマスタ |

---

## セキュリティ設計

「学生限定のクローズドな空間」を成立させるため、**アプリ側の実装を信用しない**方針で設計しています。クライアントを改造されても成立する制約を、Firestore / Storage のセキュリティルールとサーバーサイド（Cloud Functions）に置いています。

### 1. 2層認証による在籍確認

Firebase Auth の標準認証だけでは任意のメールアドレスで登録できてしまうため、大学への在籍を確認する2層目を独自に実装しました。

1. **第1層** — メールアドレスとパスワードによるアカウント作成
2. **第2層** — 大学ドメイン（`mail*.doshisha.ac.jp` / `dwc.doshisha.ac.jp`）宛に6桁の確認コードを送信

第2層の処理はすべて Cloud Functions（サーバーサイド）で実行されます。

- 確認コードは **SHA-256 でハッシュ化して保存**（平文は保存しない）
- **送信回数の上限**（1時間あたり3回）、**試行回数の上限**（1コードにつき5回）、**有効期限**（30分）
- 認証状態を保持するフィールドは、セキュリティルール側でクライアントからの更新を禁止

### 2. 権限設計（3ロール）

学生 / 団体 / 運営の3ロールを定義し、運営権限は **Firebase Auth の Custom Claims** で判定しています（メールアドレスの文字列比較ではないため、クライアントからの偽装ができません）。

主な制約：

- **自己昇格の防止** — 学生認証の状態を保持するフィールドは、更新時だけでなく**作成時にも**持てないようにしてあります（ドキュメントを削除して作り直す経路を塞ぐため）
- **自己承認の防止** — 団体は作成時のステータスが「申請中」に固定され、自身で審査ステータスを書き換えることはできません
- **審査済み団体のみが行動可能** — スカウト送信・イベント作成は、運営が承認した団体に限定されます
- **個人情報の隔離** — 認証メタデータは `users/{uid}/private` に分離し、クライアントからは書き込み不可・団体からは参照不可

### 3. スカウトの定型文化（自由記述の排除）

スカウトの本文は**5種類の定型文**から選ぶ方式で、自由記述はできません。これを利用規約や運用ルールではなく、**セキュリティルール上の制約**として実装しています。

定型文に埋め込む値も検証対象で、たとえば「興味タグに共感しました」を送るには、そのタグが**対象の学生が実際に登録しているタグ**である必要があります。イベントへの招待も、**自団体が実際に公開しているイベント**でタイトルが一致していなければ保存できません。

さらに、**ブロックされた団体からのスカウトは作成そのものが拒否**されます。これもクライアントの実装ではなくルール側で保証しています。

### 4. 通報

通報内容は運営のみが参照でき、通報者が誰かは通報された相手に開示されません。自分自身への通報、規定外の通報理由、長文の投稿はルール側で弾かれます。

### 5. ストレージ

画像ファイルのみ・5MB 以下・所有者のみ書き込み可という制約をルールで強制しています。作成／更新と削除で条件を分けて記述しており、**退会やアイコン差し替えの際に画像が確実に削除される**ようにしています。

### 6. HTTP セキュリティヘッダー

`X-Content-Type-Options` / `X-Frame-Options` / `X-XSS-Protection` / `Referrer-Policy` / `Permissions-Policy` / `Strict-Transport-Security` を設定し、Content-Security-Policy は Flutter Web（CanvasKit）と Firebase の通信先に合わせて個別に定義しています。

### 7. 資格情報の管理

Firebase の設定ファイル・署名鍵は **Git 管理から除外**し、CI では GitHub Secrets から復元しています。SMTP の資格情報は Firebase Secrets Manager で管理し、コードから分離しています。

---

## 品質保証 / CI

`.github/workflows/ci.yml` — `main` / `feat/**` / `fix/**` への push と、すべての Pull Request で実行されます。

```
push / PR
  ├─ test ──────────┬─ build-web       ← test が通らないとビルド系は走らない
  │                 ├─ build-android
  │                 └─ build-ios
  ├─ rules-test     ┐
  ├─ functions-lint │ 並列実行
  └─ security       ┘
```

| ジョブ | 内容 |
| :--- | :--- |
| `test` | `flutter analyze` による静的解析と `flutter test` |
| `rules-test` | エミュレータ上で Firestore / Storage のセキュリティルールを **74ケース**検証 |
| `functions-lint` | Cloud Functions を ESLint で検査（管理者権限で動くコードのため） |
| `security` | 秘密ファイルの混入検査と `npm audit` |
| `build-web` | 本番配信物のビルドと成果物の保存 |
| `build-android` | APK / AAB のビルド（署名は Secrets から復元） |
| `build-ios` | macOS ランナーでのビルド検証（ビルド番号を自動採番） |

**設計上の意図**

- **セキュリティルールもテストする** — ルールは316行の実行されるコードであり、変更のたびに壊れうるため、人力レビューではなく自動テストで守っています。Firestore と Storage はルールファイルも評価も別なので、必ず両方を起動して検証します。
- **秘密ファイルの混入検査を自前で持つ** — GitHub の secret scanning は「認証情報らしい文字列」しか検知しないため、設定ファイルや署名鍵の追跡状態を直接検査するステップを追加しています。
- **依存関係はロックファイル厳守** — `npm install` ではなく `npm ci` を使い、ロックファイルを更新しない限り依存の中身が変わらないようにしています。
- **止める基準を使い分ける** — 即時対応が必要な深刻度のみ CI を失敗させ、それ以外は毎回サマリに出力して可視化しています。常に赤い CI は誰も見なくなるためです。

### 依存関係の監視（Dependabot）

`functions` / Flutter 本体 / ルールテスト / GitHub Actions 自体の**4つ**を監視対象にしています。

公開直後のバージョンには飛びつかないよう **cooldown**（パッチ7日 / マイナー14日 / メジャー30日）を設定しています。近年の npm サプライチェーン攻撃では、侵害されたバージョンが公開されていた期間が数時間から1日程度だったため、更新を待つだけで大半を回避できるという判断です。GitHub Actions 自体を対象に含めているのは、Actions が侵害された場合に CI の Secrets が漏れうるためです。

---

## セットアップ

### 前提

- Flutter SDK 3.41.2（CI と同一）
- Node.js 22
- Firebase CLI / FlutterFire CLI

### 手順

```bash
git clone https://github.com/nishikawataishi/D-Hub.git
cd D-Hub
flutter pub get
```

Firebase の設定ファイルは Git 管理から除外しているため、自分の Firebase プロジェクトに接続して生成してください。

```bash
firebase login
flutterfire configure    # lib/firebase_options.dart が生成される
```

```bash
flutter run -d chrome
```

### セキュリティルールのテスト

```bash
cd firestore-tests
npm ci
firebase emulators:exec --only firestore,storage --project demo-rules-test \
  "node --test rules.test.mjs storage.rules.test.mjs"
```

### デプロイ

```bash
flutter build web --release       # ← 必ずビルドしてから
firebase deploy --only hosting
firebase deploy --only functions
firebase deploy --only firestore:rules,storage
```

<!-- TODO: エミュレータでの動作確認手順、環境変数まわりを追記 -->

---

## プロジェクト構成

```
lib/
  ├── models/       データモデル（Freezed / json_serializable）
  ├── screens/      画面（22ファイル）
  │   └── components/  共通コンポーネント
  ├── services/     Firestore / Auth / Storage / 画像処理
  └── theme/        デザイントークン
functions/          Cloud Functions（6関数）
firestore-tests/    セキュリティルールのテスト（74ケース）
firestore.rules     Firestore セキュリティルール
storage.rules       Storage セキュリティルール
lp/                 サービス紹介ページ
```

---

## ライセンス

本リポジトリにはライセンスを設定していません。著作権は作者に帰属し、無断での利用・複製・再配布はできません。

<!-- TODO: ライセンスを明示する場合は LICENSE ファイルを追加する -->
