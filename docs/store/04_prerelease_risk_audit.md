# D-Hub 1.0 審査提出前リスク監査

**実施日**: 2026-08-25 / **対象**: main @ c312956 / ASC バージョン 1.0（PREPARE_FOR_SUBMISSION・ビルド6紐付け済み）

7観点で並列調査したうえで、指摘は実ファイルで裏取りしている。
検証状況は各項目に明記した。**コードは一切変更していない。**

- ✅ **確認済** — 実ファイル・実データ・実際のHTTPレスポンスで裏を取った
- ⚠️ **未検証** — 調査エージェントの指摘。裏取り担当がセッション上限で落ちたため未確認

---

## 0. 結論

> **2026-08-25 追記 — 監査の完了前に提出済み。** ASC の状態は `WAITING_FOR_REVIEW`。
> ビルド6 = コミット `c312956` なので、**下記の指摘は提出済みバイナリにそのまま入っている**
> （ビルド6のワークフロー実行 14:21 UTC > `713ac48` の 13:50 UTC で確認）。
> 方針は「承認されればそのまま公開、差し戻されたらまとめてビルド7」。実行順は ⑤ を参照。

潰すべきものが6件ある。うち2件（大学校章・スクリーンショット）は、
通ってしまった場合のほうが後始末が重い。

| # | 内容 | 軸 | 状態 |
|---|---|---|---|
| 1 | アプリアイコンとログイン画面に同志社大学の校章 | 審査・法務 | ✅ |
| 2 | ストアのスクショが「【デモ】」だらけ＋削除済みUIが写っている | 審査 | ✅ |
| 3 | イベント一覧のカレンダーボタンが iOS で嘘をつく | コード | ✅ |
| 4 | 「シェア機能は準備中です」の死んだボタンが残っている | コード | ✅ |
| 5 | 審査中・却下団体の全データが全ユーザーに配信されている | セキュリティ | ✅ |
| 6 | 他人のUIDで団体文書を先取りでき、その学生のアプリを壊せる | セキュリティ | ✅ |

---

# ① 審査面

## 1-1. 【最優先】アプリアイコンとログイン画面に同志社大学の校章 — Guideline 5.2.1 ✅

`assets/icon/app_icon.png`（App Store に出る 1024×1024 のアイコン本体）を開くと、
無限大マークの右側に**紫の三角形が3つ組まれた同志社大学の校章がそのまま埋め込まれている**。
背景の紫も大学のスクールカラー。

同じ画像の単体版が `assets/images/doshisha_mark.png` として `pubspec.yaml` の
assets に登録され、`lib/screens/login_screen.dart:183` で**アプリのロゴとしてログイン画面の
最上部に表示**されている。起動して最初に見える画面がこれになる。

さらに ASC のサブタイトルが実データで
`サークルから『スカウト』が届く。同志社生限定プラットフォーム`（30字・上限ぴったり）になっており、
**大学名がストア掲載情報の最も目立つ位置に入っている**。

矛盾しているのは、`lib/screens/terms_screen.dart:36`（利用規約 第1条2）が

> 本サービスは同志社大学・同志社女子大学の公式サービスではなく、学生有志が個人で開発・運営しています。

と明記している点。**規約で「公式ではない」と言いながら、アイコンとログイン画面で大学の校章を
掲げている。**「公式だと誤認させない」という主張が成り立たない構成になっている。

`docs/store/01_app_store_listing.md:107` 自身が、キーワード欄について
「他者の商標をキーワードに使うと 5.2.1 で指摘される可能性がある」と警告している。
キーワードからは外したのに、**アイコン・ログイン画面・サブタイトルという、より露出の大きい
3箇所には入ったまま**になっている。

**リスク**
- Apple: Guideline 5.2.1（知的財産）。第三者の商標・ブランドの無許諾使用。差し戻し理由になる。
- 大学: こちらのほうが重い。同志社の校章は商標登録されている。公開後に大学から
  停止要請が来た場合、アイコン差し替えは新バージョンの審査が要る＝数日サービスが不整合になる。

**推奨（提出前必須）**
- アイコンから三角形マークを外し、`D∞` と `Hub` だけのデザインにする。
- `login_screen.dart:183` のロゴを自作マークに差し替える（`doshisha_mark.png` を assets から外す）。
- ASC のサブタイトルから「同志社生限定」を外す。原稿の `サークルからスカウトが届く` に戻すか、
  `学内のサークルと学生をつなぐ` のように大学名を含まない表現にする。
- 大学から正式に許諾を得ているなら、その旨を審査メモに書けば使用してよい。
  許諾があるかどうかがこの判断の分岐点になる。

---

## 1-2. 【提出前必須】ストアのスクリーンショットが二重に不適切 — Guideline 2.3.3 ✅

ASC には7枚アップロード済み（`01_scout` → `06_moderation` → `00_login` の順）。
ファイルの実体は `docs/store/screenshots/` にあり、**全ファイルのタイムスタンプが 2026-08-05**。

### (a) 「【デモ】」表示だらけ

2枚目 `02_home.png`（ストアで実際に見られる最初の3枚に入る）は、団体カードが全て

- タイトル: 「**【デモ】**アカペラサー…」「**【デモ】**テニスサークル」「**【デモ】**バスケットボ…」
- 説明: 「アカペラサークルの**デモ用プロフィールです。ストア審査のた**…」

になっている。しかも全カードに**認証済みバッジ（✓）が付いている**。
「団体は運営の審査を通過したものだけ」という説明文の主張と、絵面が食い違う。

Apple はプレースホルダ／ダミーと分かるコンテンツを含むスクリーンショットを差し戻す。
仮に通っても、ストアの商品ページに「デモ用プロフィールです」と書かれた画像が並ぶ。

### (b) アプリから削除済みのUIが写っている

- `02_home.png`: ホーム画面右上に**通知ベルアイコン**がある
- `05_mypage.png`: 設定リストに「**通知設定**」タイルがある

どちらもコミット `7921fcd`（2026-08-24 13:16）「反応しない通知UIを削除」で消してある。
ビルド6のアップロードは同日 14:21 なので、**提出ビルドにはもう存在しないUI**。

撮影 8/05 → 削除 8/24 → ビルド6 8/24 という順序なので、スクショだけが2週間分古い。

**推奨（提出前必須）**
- ビルド6と同じコードでスクショを撮り直す。
- 撮影前にデモ団体の名前から「【デモ】」を外し、説明文を実際のサークル紹介文らしい文面にする
  （`scripts/review_seed.js:184` の `【デモ】${org.name}` と説明文テンプレート）。
- 撮り直したら ASC の7枚を差し替える。`00_login.png` はアイコン／ロゴ変更後に撮ること（1-1）。

---

## 1-3. 年齢レーティングの回答が実装で裏付けられない ✅

ASC の実データ:

```
ageAssurance             : true
socialMedia              : true
socialMediaAgeRestricted : true
userGeneratedContent     : true
```

審査メモ §6 はこう説明している:

> Only students holding an email address issued by the two universities named in
> section 1 can register, so every account belongs to an enrolled university
> student. This is the basis for the age assurance answer.

**この根拠が2つの意味で成り立っていない。**

1. **団体アカウントは大学メールが要らない。** `lib/screens/login_screen.dart:45` は
   `if (_isSignUpMode && !_isOrganizationMode)` のときだけドメインを検証する。
   団体は `example@gmail.com` でも登録できる（ログイン画面のヒントもそうなっている）。
   公開中の `docs/support.html:69` も **「学内団体としてのご登録は、上記以外のメールアドレスでも可能です」**
   と明記している。「every account belongs to an enrolled university student」は事実に反する。
2. **大学メールは年齢確認ではない。** 生年月日を一切収集していない（`lib/models/user_profile.dart` に
   年齢に相当する項目は `grade` のみ）。年齢が分からない以上、
   `socialMediaAgeRestricted: true`（年齢によって機能を制限している）も実装上不可能。

さらに利用規約 第15条（`terms_screen.dart:126`）は
**「18歳未満の方が本サービスを利用する場合は、保護者の同意を得たうえでご利用ください」**
と、18歳未満の利用を前提に書いてある。ageAssurance の申告と正面から矛盾する。

**推奨（提出前に判断）**
`ageAssurance` / `socialMediaAgeRestricted` を実態に合わせて false に直すのが素直。
レーティングが上がる可能性はあるが、実装で裏付けられない申告を残すほうが危ない。
`socialMedia: true` / `userGeneratedContent: true` はそのままでよい。

---

## 1-4. マーケティングサイトが未実装機能を宣伝している ✅

ASC に登録済みのマーケティングURL `https://www.d-hub-link.com`（HTTP 200）に、こう書かれている:

> プロフィールや興味タグをもとに、団体から直接スカウトメッセージが届きます。
> **リアルタイム通知で見逃しません。**

通知機能は実装されていない。`firebase_messaging` は依存に無く、通知UIの入口は
コミット `7921fcd` で「未実装だから」という理由でわざわざ削除している。

審査担当者はマーケティングURLを開く。Guideline 2.3.1（存在しない機能の宣伝）。

**推奨（提出前必須）** サイトから「リアルタイム通知」の記述を削除する。
サイトを直せないなら、ASC のマーケティングURLは任意項目なので**空にして提出する**のが早い。

> ⚠️ 未検証: 同サイトが「自由記述のスカウト」も宣伝しているという指摘があったが、
> 私が取得した範囲では該当文言を確認できなかった。サイト全文を目視で確認すること。

---

## 1-5. 公開ドキュメント同士が矛盾している ✅

| 主張 | 場所 | 食い違う相手 |
|---|---|---|
| 通報は**24時間以内**に確認 | 規約第7条3 / ストア説明文 / 審査メモ §2 | `docs/support.html:47`「返信の目安：**3営業日以内**」 |
| **学外の人は登録できません** | ストア説明文 | `docs/support.html:69`「団体は上記以外のメールアドレスでも可能」 |

どちらもサポートURLとして ASC に登録済みで、審査担当者が確実に開くページ。
自分のサイト内で矛盾していると、1.2 の対応状況そのものの信頼性を疑われる。

**推奨（提出前必須）** support.html を規約に合わせる。通報の確認は24時間、
問い合わせの返信は3営業日、と**分けて書く**のが実態にも合う。
説明文の「学外の人は登録できません」は「学生として登録できるのは〜の学生だけです」に直す。

---

## 1-6. ASC の掲載情報と原稿が同期していない ✅

| 項目 | `scripts/asc/metadata.json`（書き込み元） | ASC の実データ |
|---|---|---|
| サブタイトル | `サークルからスカウトが届く` | `サークルから『スカウト』が届く。同志社生限定プラットフォーム` |
| 説明文 | 856字 | 856字（一致） |
| キーワード | 13語 | 13語（一致） |

サブタイトルだけ画面で手直しされ、原稿に戻されていない。
**この状態で `node scripts/asc/write_text.js` を実行すると、ASC 側が原稿の古い値に巻き戻る。**
（1-1 の対応で結果的に直すことになるが、順序を間違えると事故る）

**推奨** サブタイトルを決めたら、まず `metadata.json` を直し、そこから ASC へ書き込む。

---

## 1-7. App Privacy の申告状態が API から確認できない ⚠️

`scripts/asc/status.js` の出力:

```
── アプリのプライバシー ──
   公開状態          : (未設定)
   登録済みデータ利用  : (未設定)
```

**ASC のプライバシー申告には API が無い**ことが既に実測で分かっているため、
この「(未設定)」は API の制約かもしれず、本当に未入力なのかは判別できない。

ただし App Privacy が未入力だと ASC は提出をブロックする。

**推奨（提出前必須）** ASC の画面で「Appのプライバシー」を目視確認する。
入力内容は `ios/Runner/PrivacyInfo.xcprivacy` と一致させること
（食い違うと 5.1.1 で差し戻される）。対応表は `docs/store/01_app_store_listing.md` §7。

---

## 1-8. 本番のデモデータ ✅（承認後の作業）

`scripts/review_seed.js` が本番 Firestore に投入している:

- 団体 11件（`status: "verified"`）… `【デモ】バスケットボール同好会` など
- 学生 5件（`isStudentVerified: true`）… `デモ 学生A` 〜 `E`
- スカウト3件・イベント2件

うち Auth ユーザーがあるのは `review-student` と `review_org` の2つだけ。
残りは**ログインできない認証済み団体**として一覧に居座る。

Web版は同じ Firestore を見ているので、URL を知っている人には既に見えている。

**推奨** 承認 → 公開後すみやかに `node scripts/review_seed.js delete --yes-production`。
ただし削除すると団体一覧が空になるので、**実在サークルの登録を何団体か先に済ませてから**
消す段取りにしておくこと。

---

# ② コード・機能面

## 2-1. 【提出前必須】イベント一覧のカレンダーボタンが iOS で嘘をつく — Guideline 2.1 ✅

`lib/screens/event_screen.dart:164-198`

```dart
onCalendarTap: () async {
  if (kIsWeb) {
    ...  // Google Calendar を launchUrl
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📅 「${event.title}」をカレンダーに追加しました')),
    );
  }
},
```

**iOS では `kIsWeb` が false なので `if` の中身を素通りし、何もせずに
「カレンダーに追加しました」とだけ表示する。** カレンダーには1件も入らない。

イベント**詳細**画面（`event_detail_screen.dart:321`）は `Add2Calendar.addEvent2Cal()` を
正しく呼んでいて動く。コミット `713ac48`「カレンダー導線の表示と権限文を実態に合わせる」は
**詳細画面だけを直していて、一覧画面が漏れている**（変更ファイルは
`event_detail_screen.dart` と `Info.plist` の2つのみ）。

ストア説明文は「気になるイベントはアプリから申し込みでき、カレンダーアプリに予定を
追加することもできます」と宣伝している。審査担当者はイベント一覧のカレンダーアイコンを押す。

**推奨（提出前必須）** 一覧のボタンも詳細画面と同じ実装にするか、一覧からボタン自体を外す。

---

## 2-2. 【提出前必須】「シェア機能は準備中です」の死んだボタン — Guideline 2.1 ✅

`lib/screens/group_detail_screen.dart:73-80`

```dart
IconButton(
  icon: const Icon(Icons.share),
  onPressed: () {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('シェア機能は準備中です')));
  },
),
```

団体詳細画面のアプリバー右上。**スクリーンショット3枚目がこの画面**なので、
審査担当者はほぼ確実に開く。

コミット `7921fcd` は「押しても何も起きない要素は Guideline 2.1 で指摘されうるため、
審査提出前に入口ごと消す」という理由で通知UIを削除している。**同じ基準に照らせばこれも消す対象**
だが、消し漏れている。

**推奨（提出前必須）** IconButton を削除する（`actions` には ModerationMenu が残るので
`actions` ごと消さないこと）。

---

## 2-3. 学生認証コードが届かないとアカウントが詰む ⚠️

`lib/screens/student_verify_screen.dart`

登録メールを打ち間違えた／コードが迷惑メールに入って気づかない場合、
**認証済みになるまで `StudentVerifyScreen` から先に進めない**。
`AuthGate` は `AuthStatus.studentUnverified` の間このの画面しか返さない（`main.dart:93-94`）。

逃げ道はアプリバーのログアウトボタン（`student_verify_screen.dart:135`）だけで、
ログアウトしても同じアカウントで入り直せば同じ画面に戻る。
退会導線はマイページの中にあり、この画面からは到達できない。

**リスク** 審査担当者はデモアカウント（認証済みで投入済み）を使うので審査では詰まらない。
ただしリリース後の実ユーザーのサポート負荷になり、
「アプリ内でアカウントを削除できること」（5.1.1(v)）が**この状態のユーザーには満たされていない**。

**推奨（承認後でよいが早めに）** この画面から「メールアドレスを変更する」または
「退会する」に到達できるようにする。

---

## 2-4. 退会がフェーズ2で失敗すると二度とやり直せない ✅（設計の読み取りで確認）

`functions/index.js:325` 付近。`deleteMyAccount` は

1. フェーズ1: `organizations/{uid}` と `users/{uid}` を消す＋リフレッシュトークン失効
2. フェーズ2: スカウト・申し込み・イベント・ブロック・Storage
3. 失敗が1件でもあれば `throw`（Auth ユーザーは残す＝やり直せるように）

という設計で、権限失効を先に置く判断は正しい。**ただし「やり直せる」が成立していない。**

フェーズ1で `users/{uid}` が消えた時点で、次回ログイン時の `_resolveUserStatus`
（`auth_notifier.dart:88-110`）は users も organizations も見つけられず、2回リトライして
`AuthStatus.error` になる。エラー画面に出るのは「再試行」と「ログアウト」だけで、
**退会をもう一度呼ぶ導線が存在しない**（退会はマイページの中）。

コメントの「この関数は冪等なので、再ログインしてもう一度呼べば続きから掃除できる」は
サーバ側の性質としては正しいが、**クライアントにその「もう一度呼ぶ」手段が無い**。

**推奨** エラー画面に「アカウント削除を再試行」を追加するか、
フェーズ1の `users/{uid}` 削除を最後に回す（権限失効は
`revokeRefreshTokens` + `organizations/{uid}` 削除で足りるか要検討）。

---

## 2-5. 団体審査の根拠となる証明画像が実際には集まっていない ✅

`OrgCreateScreen`（`lib/screens/org_create_screen.dart`）は活動実態の証明画像をアップロードし
`proofImageUrl` を保存する画面で、管理画面（`admin_dashboard_screen.dart:298, 765`）は
この画像を見て承認可否を判断する設計になっている。

しかし**この画面への唯一の入口は `org_dashboard_screen.dart:644`の「団体が登録されていません」
空状態のボタン**で、その空状態には到達しない。団体として新規登録すると
`auth_notifier.dart:_createUserDocument` が**サインアップ時点で `organizations/{uid}` を
`status: 'pending'` で必ず作る**ため、ダッシュボードは常に「審査待ち」バナーを表示する。

結果、`proofImageUrl` は常に空。**運営は何の証拠も見ずに承認することになる。**

ストア説明文・審査メモの「団体アカウントは運営が実在を確認したうえで公開されます」
「Club accounts are published only after the operator confirms that the club actually exists」
という 1.2 対応の主張の根拠が、実装上は存在しない。

**推奨** 審査で直接突かれる可能性は低いが、1.2 の主張を裏付ける仕組みなので
承認後すぐに導線を通すこと。運用で代替する（メールで証明を受け取る）なら、
support.html にその手順を書いて実在させる。

---

## 2-6. イベントを削除すると申込者の個人情報が孤児として永久に残る ✅

`lib/services/firestore_service.dart:302`

```dart
Future<void> deleteEvent(String eventId) async {
  await _db.collection('events').doc(eventId).delete();
}
```

サブコレクション `events/{id}/applications` を消していない。Firestore は親を消しても
サブコレクションが残る。applications には申込学生の**氏名・学部・学年**が入っている。

さらに悪いことに、`firestore.rules:175` のコメントが警告しているとおり、
applications の delete 判定は `get(/events/$(eventId)).data.organizationId` を参照する。
**親イベントが消えた後は参照先が無く、団体も学生も二度と削除できない。**
管理者（`isAdmin()`）だけが消せる。

規約第14条2「退会すると、アカウントおよび登録データは削除されます」の担保も崩れる
（`deleteMyAccount` は `collectionGroup('applications').where('studentId','==',uid)` で
拾うので退会時は消えるが、イベント削除が先行したケースでは孤児のまま残る）。

**推奨** `deleteEvent` で applications を先に消してからイベントを消す
（順序は rules のコメントどおり applications が先）。

---

## 2-7. その他（承認後でよい）⚠️ 未検証を含む

| 内容 | 場所 |
|---|---|
| 団体のカテゴリーが空だと詳細画面が `List.first` でクラッシュ | `group_detail_screen.dart:162` |
| ブロックした団体の未読スカウトでタブバッジが消えなくなる | `main_screen.dart:62` |
| 学生が新しい興味タグを追加すると `permission-denied` の未処理例外（tags の create は `isVerifiedOrg()` のみ許可） | `profile_screen.dart:70` / `firestore.rules:311` |
| 学年・キャンパス未設定の学生にスカウトを送ると生の `permission-denied` が出る | `scout_compose_dialog.dart:88` |
| 写真選択で例外が起きても何も表示されない（押しても無反応に見える） | `image_service.dart:188` |
| ブロックした団体のイベントは一覧に出続け、そこから団体詳細も開ける | `event_screen.dart:55` |
| Instagram URL 未設定の団体でも「Instagramで連絡する」が出て Instagram トップが開く | `scout_detail_screen.dart:43` |
| 審査待ち団体に「右下の＋ボタンから作成」と案内するが＋ボタンが無い | `org_dashboard_screen.dart:432` |
| イベントを編集し直すと `organizationCategory` が「すべて」に書き換わる | `models/event.dart:103` |
| `flutter analyze` は 30件すべて info。うち `use_build_context_synchronously` 4件（`event_edit_screen.dart` 3・`student_verify_screen.dart` 1） | ✅ 実行して確認 |
| Flutter のテストは `test/widget_test.dart` 1本のみ。ルールのテストは58本あり厚い | ✅ |

---

# ③ セキュリティ面

## 3-1. 【提出前必須】審査中・却下団体の全データが全ユーザーに配信されている ✅

`firestore.rules:81`

```
allow list: if isAdmin() || isAuthenticated();
```

OR の右辺だけで常に真になるので実質 `isAuthenticated()`。
すぐ上の `allow get`（75-79行）は `status == 'verified'` か本人か管理者に絞っているのに、
**list がその制限を完全に迂回する。**

クライアント側も無防備で、`firestore_service.dart:54` の `getOrganizations()` は

```dart
_db.collection('organizations').orderBy('name').snapshots()
```

と**status 条件なしで全件をリアルタイム購読**している。
`status == 'verified'` の絞り込みは `home_screen.dart:51` のクライアント側フィルタだけ。

つまり**審査中(pending)・却下(rejected)の団体ドキュメントが、ホーム画面を開くたびに
全学生の端末へ実際にダウンロードされている**。中身は団体名・紹介文・`representativeId`
（代表者の Firebase UID）・Instagram / グループLINEのURL・`proofImageUrl`・status。

任意のログインユーザーが Firestore SDK を直に叩けば、画面に出ないものも含めて全件取れる。

プライバシーポリシー §3「第三者に提供しません」§5「不正アクセス…漏洩の防止に努めます」
とも整合しない。

**推奨（提出前必須）**

```
allow list: if isAdmin()
            || (isAuthenticated() && resource.data.status == 'verified')
            || isOwner(resource.data.representativeId);
```

にしたうえで、`getOrganizations()` に `.where('status', isEqualTo: 'verified')` を付ける
（`status` + `name` の複合インデックスを `firestore.indexes.json` に追加）。
管理画面は `getOrganizationsByStatus` / `getAllOrganizationsForAdmin` の別経路なので影響しない。
`firestore-tests/rules.test.mjs` には organizations の list テストが1本も無いので、
同時にテストも足すこと。

## 3-2. 【提出前必須】他人のUIDで団体文書を先取りでき、その学生のアプリを壊せる ✅

`firestore.rules:84`

```
allow create: if isAuthenticated() &&
              request.resource.data.status == 'pending' &&
              request.resource.data.representativeId == request.auth.uid;
```

**docId に対する制約が無い。** `representativeId` が自分であれば、ドキュメントIDは何でもよい。

攻撃の形:

1. 承認済み団体は `allow list: if isVerifiedOrg()`（32-33行）で**全学生の users を一覧できる**
   → 狙った学生の UID が手に入る
2. `organizations/{被害者のUID}` を `representativeId: 自分のUID`, `status: 'pending'` で作成
3. 被害者が次にログインすると `auth_notifier.dart:_resolveUserStatus` が
   `organizations/{uid}` の存在を先に見るため、**学生なのに団体ダッシュボードへ飛ばされる**

被害者は `isVerifiedOrg()` が false なのでスカウトも送れず、学生画面にも戻れない。
ルール上は `isOwner(docId)` で自分で削除できるが、**それを実行するUIがアプリに無い**。

情報漏洩ではないが、**任意の学生のアカウントを一方的に使用不能にできる**。

**推奨（提出前必須）** create に `docId == request.auth.uid` を足す。
`_createUserDocument` は元から `doc(user.uid)` を使っているので、正規の登録には影響しない。

## 3-3. 承認済み団体が users を全件読める設計 ✅

`firestore.rules:32-33`

```
allow get:  if isOwner(userId) || isVerifiedOrg() || isAdmin();
allow list: if isVerifiedOrg() || isAdmin();
```

**メールアドレスは users に書かれていない**ことは確認できた
（`auth_notifier.dart:346` は `isStudentVerified` と `createdAt` だけを書き、
コメントも「emailはFirebase Auth側で管理（usersドキュメントは団体に公開されるため保存しない）」
と明記。大学メールは `users/{uid}/private/verification` に隔離され、
クライアントからは管理者すら書けない）。この設計は正しい。

残る問題は**開示していないこと**（1-9 参照）と、
学生認証がまだ済んでいないユーザーまで一覧に載ること。

## 3-4. 認証コード送信のレート制限が並行呼び出しで抜ける ⚠️

`functions/index.js:69`（読み取り）→ `:107`（書き込み）が read-then-write で、
トランザクションになっていない。同時に複数呼べば
「1時間3回」の判定が全て古い値を見て通る可能性がある（TOCTOU）。

実害は大学のメールサーバへの送信集中と、送信元 Gmail アカウントの送信上限・スパム判定。
コード自体はサーバ生成なので認証は破られない。

あわせて `verifyCode` の成功時（`:246`）に
`codeSentCount` / `codeSentWindowStart` ごと削除しているため、**認証に成功するたび
送信レート制限がゼロに戻る**。

**推奨** `db.runTransaction` に包む。`verifyCode` の成功時にレート制限カウンタを消さない。

## 3-5. 大学メールアドレスの一意性が担保されていない ⚠️

`functions/index.js:109` は `users/{uid}/private/verification` に `universityEmail` を
書くだけで、**同じ大学メールが別UIDで既に使われていないかを見ていない**。

同一の大学メールで、認証済み学生アカウントを何個でも作れる。
規約第3条4「1人のユーザーが複数の学生アカウントを保有することはできません」の担保が無い。
コードはメールに届くので他人のアカウントは奪えないが、
自分のメールで複数アカウントを量産することは止められない。

## 3-6. onCall 6関数すべてに App Check が無い ⚠️

アプリ外から直接エンドポイントを叩ける。`sendVerificationCode` を回されると
メール送信コストとレピュテーションが減る。3-4 と組み合わせると影響が大きくなる。

**推奨** `onCall({ enforceAppCheck: true })`。ただし App Check の導入は
iOS 側の設定（DeviceCheck / App Attest）が要るので、**このリリースには含めず次で入れる**判断でよい。

## 3-7. その他（承認後でよい）⚠️

| 内容 | 場所 |
|---|---|
| 認証コード送信ログに大学メールを平文で記録（学籍番号相当のPII） | `functions/index.js:160` |
| `setAdminClaim` が既存クレームを `{admin:true}` で丸ごと上書き。自分の admin を外せる安全弁も無い | `functions/index.js:448` |
| 管理者による学生削除がスカウト・申し込み・Storage を残す（`deleteMyAccount` と非対称） | `firestore_service.dart:771` / `admin_dashboard_screen.dart:644` |
| `reports.snapshot` と `contacts` にサイズ・型・レート制限が無い | `firestore.rules:265` |
| reports の必須キーに `createdAt` が無く、無いと管理画面のクエリ（`orderBy('createdAt')`）に出てこない | `firestore.rules:267` |
| Storage の contentType 検証はクライアント申告依存で偽装可能。アップロード件数上限も無い | `storage.rules:14` |
| 退会1回ごとに `collectionGroup('blocks')` を全件走査。規模拡大でタイムアウト | `functions/index.js:371` |
| クライアントとサーバの大学メール正規表現が不一致（`mail10@` はクライアント通過・サーバ拒否） | `auth_service.dart:17` / `functions/index.js:18` |
| `/admin` ルートが MaterialApp に登録済み。Web ビルドは URL 直打ちで AuthGate を迂回できる（データはルールで守られている） | `main.dart:67` |
| `docs/` 全体が GitHub Pages で公開。iOSリリース手順書・審査メモ・審査用データの運用手順まで誰でも読める | `docs/store/03_ios_release_runbook.md` |

**良かった点**（監査で問題が無いことを確認したもの）

- 秘密ファイルの混入なし。`.p8` / `.mobileprovision` / `GoogleService-Info.plist` /
  `firebase_options.dart` はいずれも**Git 履歴にも一度も入っていない**（`git log --all --diff-filter=A` で確認）
- `seedData()` は `kDebugMode` ガードで本番実行不可
- 退会時の再認証は `reauthenticateWithCredential` → `getIdToken(true)` の順で、
  サーバ側の `auth_time` 10分以内チェックと整合している
- スカウトの定型文検証はルールとクライアントのペイロードが完全に一致（`toFirestore()` が
  null のキーを出さないので、`templateId==4` の `!hasAny(['templateArg','templateEventId'])` も通る）
- Firestore ルールのテストが58本あり、ブロック・通報・スカウト定型文・権限昇格を厚く押さえている
- `npm ci` 固定・`npm audit --audit-level=critical` を CI に組み込んでいる
- サポートURL・プライバシーポリシーURL・マーケティングURLは3本とも HTTP 200

---

# ④ プライバシー・法務

## 4-1. 「承認済み団体が全学生のプロフィールを閲覧・検索できる」ことがどこにも書かれていない ✅

これがアプリの中核機能（審査メモにも「Student search. Browse students and send a scout.」と
明記している）にもかかわらず、**利用規約にもプライバシーポリシーにも記載が無い**。

- 規約 第5条（スカウト機能）は定型文の話しかしていない
- ポリシー §3「情報の第三者提供」は
  **「ユーザーの個人情報は、以下の場合を除き、第三者に提供しません」**と書いている

学生から見ると、氏名・学部・学年・キャンパス・興味タグ・**プロフィール写真**が、
承認済みの全団体に一覧・検索されていることを知る手段が無い。

Guideline 5.1.2（データの利用と共有）に加えて、個人情報保護法上も説明が要る。

**推奨（提出前必須）** ポリシー §1 か新設の節に
「学生ユーザーが登録したプロフィール（氏名・学部・学年・キャンパス・興味・写真）は、
運営の審査を通過した団体ユーザーが閲覧・検索できます」を明記する。
`docs/privacy-policy.html` と `lib/screens/privacy_policy_screen.dart` の**両方**を直すこと
（現状は同じ内容で同期している。片方だけ直すと崩れる）。

## 4-2. 退会後も reports / contacts を残すことが書かれていない ✅

`functions/index.js` のコメントは意図的な設計だと明言している:

> あえて消さないもの: reports / contacts
> 通報・問い合わせは運営の対応記録（規約第7条）で、通報者保護のためにも
> 被通報者の退会で消えてはいけない。

一方、外向きの文言は全て「全部消える」と言っている:

- 規約 第14条2「退会すると、アカウントおよび登録データは削除されます」
- 退会ダイアログ「以下のデータが即座に完全削除されます」（`delete_account_dialog.dart:26`）
- support.html「アカウントと登録データは即座に完全に削除されます」

**推奨（提出前に文言修正）** 規約第14条に
「ただし、通報およびお問い合わせの記録は、運営の対応記録として保持することがあります」を追加。

なお退会ダイアログの列挙（`profile_screen.dart:505`）にはプロフィール写真・
受け取ったスカウト・イベント申し込みが入っていない。実際には削除されるので
**過少申告**であり危険な方向ではないが、揃えておくとよい。

## 4-3. 通報「24時間以内」の約束を担保する実装が無い ⚠️

規約第7条3・ストア説明文・審査メモの3箇所で「24時間以内に確認する」と約束しているが、
新しい通報を運営に知らせる仕組み（Firestore トリガー・メール・プッシュ）が一つも無い。
管理者が `admin_dashboard_screen` を自分で開くまで、通報があったことに気づけない。

審査で試されることはまずないが、書いた以上は守る対象になる。

**推奨** 文言を「速やかに」に緩めるか、`onDocumentCreated('reports/{id}')` で
運営宛にメールを送る Function を足す（`nodemailer` は既に入っている）。

## 4-4. ポリシーの記載漏れ・不足 ⚠️

- 「取得する情報」に**お問い合わせ本文・ブロック情報・認証メタデータ（試行回数等）・
  スカウトに複製される氏名/アイコンURL**が入っていない
- **運営者の氏名・住所が無い**（`dhublink.support@gmail.com` のみ）。
  個人情報保護法上、個人情報取扱事業者の氏名・住所は本人の知り得る状態に置く必要がある
- 個人データの**保有期間・削除方針**の節が無い
- §9「予告なく変更することがあります」と規約第16条2「アプリ内通知等により通知します」が矛盾し、
  そもそもアプリ内通知が実装されていない
- 利用規約に**公開URLが無い**（アプリをインストールしないと読めない）。
  ポリシーだけ GitHub Pages にあり非対称

---

# ⑤ 推奨アクション

## 審査中の今、安全にできること（ビルドもASCも触らない）

審査担当者が必ず開くページで、修正コストがゼロ。**これだけは今日やってよい。**

- `https://www.d-hub-link.com` から「リアルタイム通知で見逃しません」を削除（1-4）
- `docs/support.html` の「3営業日以内」と「団体は上記以外のメールアドレスでも可能」を
  規約・説明文と整合させる（1-5）

**審査中にやってはいけないこと**

- 🔴 `firestore.rules` の `organizations` の `allow list` を絞る
  → ビルド6の全件クエリが落ち、`home_screen.dart:148` に `hasError` 分岐が無いため
  **ホーム画面が無言で「該当する団体が見つかりません」だけになる**。Guideline 2.1 で確実に落ちる。
  ルールとクライアントは必ず同時に出すこと（3-1）
- 🔴 本番のデモデータ削除 → 審査担当者が空のアプリを見る
- 🟡 ASC のメタデータ編集 → 版が審査キューから外れる場合がある

**単独でルールだけ当ててよい唯一の例外**は 3-2（`allow create` の docId 制約）。
実運用の団体登録経路は `.doc(user.uid).set()` しか無いので、ビルド6は壊れない。
3-1 より 3-2 のほうが危険（任意の学生のアカウントを使用不能にできる）なので、
急ぐならこれだけ先に閉じられる。

## 差し戻されたら、この6件をビルド7でまとめて出す

1. **アイコンとログイン画面から同志社大学の校章を外す。ASC サブタイトルから「同志社生限定」を外す**
   （許諾があるなら審査メモに書いて据え置き可）
2. **ビルド6と同じコードでスクリーンショットを撮り直す**。「【デモ】」表記を外してから撮る
3. `event_screen.dart` のカレンダーボタンを直すか外す
4. `group_detail_screen.dart` の「シェア機能は準備中です」ボタンを削除
5. `firestore.rules` の organizations: `allow list` に status 条件、`allow create` に docId 制約
6. **文言の整合** — support.html の「3営業日」と「学外の人は登録できません」、
   マーケティングサイトの「リアルタイム通知」、ポリシーへの「団体が学生を閲覧できる」明記、
   規約第14条への reports/contacts 除外

> 1〜4 と 6 の一部はコード／掲載情報の変更なので、**5 のルール変更以外は
> 新しいビルド（ビルド7）が必要**。5 は `firebase deploy --only firestore:rules` だけで済む。

## 提出前に目視で確認すること

- ASC の「Appのプライバシー」が入力済みか（API では判別できない）
- 年齢レーティングの `ageAssurance` / `socialMediaAgeRestricted` を false に直すか判断
- 配信地域が日本のみになっているか（API の v2 エンドポイントが取得できなかった）
- `https://www.d-hub-link.com` の全文を読み、実装と食い違う宣伝が他に無いか

## 承認・公開後

- `node scripts/review_seed.js delete --yes-production`（実在サークルの登録を待ってから）
- 2-3（学生認証で詰む）、2-4（退会リトライ）、2-5（証明画像の導線）、2-6（イベント削除）
- 3-4〜3-7 のセキュリティ項目。App Check は次のリリースで

---

## 付録: 監査の範囲と限界

- **調べたもの**: `lib/` 全55ファイル（14,555行）、`functions/index.js`、`firestore.rules`、
  `storage.rules`、`firestore.indexes.json`、`ios/` 設定一式、`docs/` 全体、
  `.github/workflows/`、`scripts/asc/`、ASC の実データ（読み取り専用API）、
  公開中の3サイトの HTTP レスポンス、`flutter analyze` の実行結果
- **やっていないこと**: 実機・シミュレータでの動作確認、ビルド6の IPA そのものの検証、
  本番 Firestore のデータ内容の確認、ペネトレーションテスト
- **未検証の指摘**: 調査は7観点で走らせたが、裏取り担当のエージェントが
  セッション上限で停止したため、⚠️ を付けた項目はコード上の指摘のみで再検証していない。
  ✅ の項目は私が実ファイル・実データで確認している
