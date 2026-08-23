# iOS リリース手順書（Apple Developer Program 加入後）

> ⚠️ **このファイルに認証情報を書かないこと。**
> `docs/` は GitHub Pages で公開されている。証明書・鍵・パスワードの実体は
> `ios/certs/`（gitignore 済み）と GitHub Secrets にだけ置く。

Mac は不要。証明書の作成は Windows の Git Bash（openssl）で、ビルドと
アップロードは GitHub Actions の macOS ランナーで行う。

---

## 全体像

```
[Windows/Git Bash]                [developer.apple.com]         [GitHub]
  秘密鍵 + CSR 生成  ──── CSR ────▶ Apple Distribution 証明書
        │                                    │
        │◀────────── .cer ───────────────────┘
        │
  .p12 に詰め直す
        │                          App ID 登録 (com.dhublink.app)
        │                                    │
        │                          プロビジョニングプロファイル作成
        │◀────── .mobileprovision ───────────┘
        │
        └──── base64 ────────────────────────────────▶ Secrets 登録
                                                            │
[App Store Connect]                                         │
  API キー (.p8) 発行 ──── base64 ──────────────────────────┘
                                                            │
                                          Actions → iOS Release 実行
                                                            │
                                                      TestFlight
```

所要時間の目安: 手作業 1〜2時間。CI は1回 20〜30分。

---

## 前提

- Apple Developer Program の加入が**完了**している（支払い済みかつ本人確認通過）
  - 「購入手続き済み」だけでは足りない。developer.apple.com にログインして
    Certificates / Identifiers / Profiles のメニューが開ければ完了。
- 登録種別は **Individual**（個人）。App Store の販売者名には法的な氏名が出る。

---

## Step 1 — App ID を登録する

<https://developer.apple.com/account/resources/identifiers/list>

1. ＋ → **App IDs** → **App**
2. Description: `D-Hub`
3. Bundle ID: **Explicit** を選び `com.dhublink.app` を入力
4. Capabilities は**何も追加しない**

> このアプリはメール/パスワード認証のみ（`signInWithEmailAndPassword`）で、
> `firebase_messaging` も使っていない。Push Notifications も Sign in with Apple も
> 不要で、`.entitlements` ファイルも存在しない。**素の App ID でよい。**
> 余計な Capability を付けるとプロファイルと実際の entitlements が食い違い、
> アップロード時に弾かれる。

---

## Step 2 — 配布証明書を作る

Git Bash で、リポジトリのルートから:

```bash
./tools/ios-signing-bootstrap.sh csr
```

氏名とメールアドレスを聞かれる。`ios/certs/dist.key`（秘密鍵）と
`ios/certs/dist.csr` ができる。

> **`dist.key` は絶対に消すな。** これを失うと証明書を作り直すことになる。
> 配布証明書はアカウントあたり2枚までしか持てない。

<https://developer.apple.com/account/resources/certificates/list>

1. ＋ → **Apple Distribution**
2. Choose File で `ios/certs/dist.csr` をアップロード
3. 発行された `.cer` をダウンロード

```bash
./tools/ios-signing-bootstrap.sh p12 ~/Downloads/distribution.cer
```

秘密鍵と証明書が対になっているか、Development 証明書を間違えて掴んでいないかを
検証したうえで `ios/certs/distribution.p12` とそのパスワードを生成する。

---

## Step 3 — プロビジョニングプロファイルを作る

<https://developer.apple.com/account/resources/profiles/list>

1. ＋ → **Distribution** の **App Store Connect**
2. App ID: `com.dhublink.app`
3. Certificate: Step 2 で作った証明書
4. Profile Name: `D-Hub App Store`（名前は自由。CI がファイルから自動で読む）
5. ダウンロード

---

## Step 4 — App Store Connect API キーを発行する

<https://appstoreconnect.apple.com/access/integrations/api>

「ユーザとアクセス → 統合 → App Store Connect API」でキーを生成する。

- アクセス権は **App Manager** 以上（Admin が確実）
- **`.p8` は一度しかダウンロードできない。** 必ず保存する
- 控える値: **Key ID** と **Issuer ID**

> Apple ID + アプリ固有パスワードは使わない。2FA と有効期限で CI が
> 定期的に壊れるため、API キー方式に統一してある。

---

## Step 5 — GitHub Secrets に登録する

```bash
./tools/ios-signing-bootstrap.sh secrets ~/Downloads/D_Hub_App_Store.mobileprovision
```

App Store 配布用プロファイルであること・Bundle ID が一致することを検証したうえで、
貼り付ける値を出力する。`.p8` だけは別途:

```bash
./tools/ios-signing-bootstrap.sh b64 ~/Downloads/AuthKey_XXXXXXXX.p8
```

Settings → Secrets and variables → Actions → New repository secret

| Secret 名 | 中身 | 出どころ |
|---|---|---|
| `APPLE_TEAM_ID` | Team ID（英数字10桁） | `secrets` コマンドが出力 |
| `IOS_DIST_CERT_P12_BASE64` | 配布証明書 | 同上 |
| `IOS_DIST_CERT_PASSWORD` | .p12 のパスワード | 同上 |
| `IOS_PROVISIONING_PROFILE_BASE64` | プロファイル | 同上 |
| `ASC_KEY_ID` | API キーの Key ID | Step 4 |
| `ASC_ISSUER_ID` | API キーの Issuer ID | Step 4 |
| `ASC_KEY_P8_BASE64` | .p8 を base64 化 | `b64` コマンド |

`FIREBASE_OPTIONS_DART` と `GOOGLESERVICE_INFO_PLIST` は既存 CI 用に登録済みのはず。

---

## Step 6 — preflight で検証する

Actions → **iOS Release (TestFlight)** → Run workflow
→ `preflight_only` は **true のまま**（既定値）

ビルドもアップロードもせず、次だけを確認する:

- Secrets が9件揃っているか
- .p12 が本当に PKCS#12 か、.p8 が本当に秘密鍵か
- プロファイルの Team ID / Bundle ID が一致するか
- プロファイルが App Store 配布用か（Development だと落とす）
- プロファイルの有効期限
- App Store Connect API の疎通

**ここが緑になるまで先に進むな。** ビルドを20分回してから
「Secret の登録ミス」で落ちるのが一番もったいない。

> アプリレコード未作成のため「App Store Connect への問い合わせが失敗した」と
> 出るのは**この時点では正常**。

---

## Step 7 — App Store Connect にアプリを作る

`preflight` が通ったら、ローカルまたは Actions から:

```bash
cd ios && bundle exec fastlane ios register_app
```

Actions 上で済ませたい場合は App Store Connect の UI から手動で作ってもよい。
入力値は [`01_app_store_listing.md`](01_app_store_listing.md) の「1. 基本情報」に揃えてある。

> App 名 `D-Hub` は App Store 全体で一意。既に使われていれば別名が必要になる。

---

## Step 8 — TestFlight にアップロードする

Actions → **iOS Release (TestFlight)** → Run workflow
→ `preflight_only` を **false** にして実行

| 入力 | 意味 |
|---|---|
| `build_number` | 空でよい。ワークフローの実行回数が自動で入る |
| `changelog` | 「テスト内容」。`wait_for_processing` が true のときだけ反映 |
| `wait_for_processing` | Apple 側の処理完了まで待つ。CI が10〜30分伸びる |

完了後、App Store Connect の TestFlight タブに現れるまで数分〜十数分かかる。

---

## Step 9 — 審査に出す

1. TestFlight で実機確認する
2. [`01_app_store_listing.md`](01_app_store_listing.md) の内容を App Store Connect に入力
   - 説明文・キーワード・カテゴリ・年齢レーティング・App Privacy はすべて原稿済み
   - スクリーンショットは [`screenshots/`](screenshots/) の7枚
3. 「App Review Information」に審査用アカウントを入力
   - 認証情報は `scripts/review_seed.js`（gitignore 対象・ローカルのみ）を参照
4. 配信地域を**日本のみ**に設定
5. 提出

> **審査通過後、審査用アカウントとデモデータを削除すること。**
> `node scripts/review_seed.js delete --yes-production`

---

## つまずいたとき

| 症状 | 原因と対処 |
|---|---|
| `No signing certificate "iOS Distribution" found` | .p12 がキーチェーンに入っていない。`IOS_DIST_CERT_PASSWORD` の登録ミスを疑え |
| `Provisioning profile ... doesn't match` | プロファイルの Bundle ID か Team ID の不一致。`preflight` が本来ここで止める |
| `The provided entity includes an attribute with a value that has already been used` | ビルド番号の重複。`build_number` を手入力して大きい値にする |
| `Redundant Binary Upload` | 同上 |
| `Invalid Provisioning Profile ... doesn't include the get-task-allow entitlement` | Development プロファイルを使っている。App Store 用を作り直せ |
| `Unsupported export_method` | `ios/ExportOptions.plist` の `method` は `app-store` 固定。Xcode 新名称の `app-store-connect` は fastlane(gym) の検証を通らない |
| App 名が使えない | `D-Hub` が他者に取られている。`register_app` の `app_name` を変える |

---

## 定期的に必要になること

| 対象 | 有効期間 | 切れたら |
|---|---|---|
| Apple Developer Program | 1年（自動更新） | 切れるとアプリがストアから消える |
| 配布証明書 | 1年 | Step 2 をやり直して Secret を更新 |
| プロビジョニングプロファイル | 1年 | Step 3 をやり直して Secret を更新 |
| App Store Connect API キー | 無期限 | 失効させた場合のみ Step 4 |

`preflight` はプロファイルの残り30日を切ると警告を出す。

---

## 初回実行後にやること

`ios/Gemfile.lock` を artifact（`ios-gemfile-lock`）からダウンロードしてコミットする。
fastlane とその依存のバージョンが固定され、以後のビルドが再現可能になる。
`package-lock.json` をコミットしているのと同じ理由。
