# App Store 掲載情報 下書き

App Store Connect に入力する内容の原稿。Apple Developer Program 登録前に確定できる
ものをここにまとめてある。文字数はすべて Apple の上限に収めてある。

対象アプリ: D-Hub / Bundle ID `com.dhublink.app` / バージョン 1.0.0

---

## 1. 基本情報

| 項目 | 値 | 上限 |
|---|---|---|
| App名 | `D-Hub` | 30字 |
| サブタイトル | `サークルからスカウトが届く` （13字） | 30字 |
| プライマリカテゴリ | ソーシャルネットワーキング | — |
| セカンダリカテゴリ | 教育 | — |
| 価格 | 無料（App内課金なし） | — |
| primary language | 日本語 | — |
| 配信地域 | 日本のみ | — |

**配信地域を日本のみにする理由**: 同志社大学・同志社女子大学のメールアドレスを
持つ学生しか登録できないため、他地域で配信しても利用できない。地域を絞ることで
「その地域のユーザーが使えない」という指摘を避けられる。

---

## 2. プロモーションテキスト（170字以内・審査なしで差し替え可能）

```
新歓シーズン到来。プロフィールを登録しておくだけで、あなたに興味を持ったサークルや学生団体からスカウトが届きます。自分から探しに行かなくても、新しいコミュニティとの出会いが向こうからやってくる。
```
（92字）

---

## 3. 説明文（4000字以内）

```
D-Hubは、同志社大学・同志社女子大学の学生と、学内のサークル・学生団体をつなぐアプリです。

■ 探さなくても、出会える
学部・学年・キャンパス・興味のあることを登録しておくだけ。あなたのプロフィールを見た団体から「スカウト」が届きます。自分から動くのが苦手でも、興味を持ってくれた団体の方から声をかけてもらえます。

■ 気になる団体を自分から探すことも
ジャンルやフリーワードで学内の団体を検索できます。活動内容・写真・キャンパス・連絡先をまとめて確認できるので、雰囲気をつかんでから連絡できます。

■ 学内イベントを見逃さない
新歓イベントや説明会の情報が日付ごとに並びます。気になるイベントはアプリから申し込みでき、カレンダーアプリに予定を追加することもできます。

■ 安心して使うための仕組み
・大学のメールアドレスによる本人確認
　登録できるのは同志社大学・同志社女子大学のメールアドレスを持つ学生だけです。学外の人は登録できません。

・団体は運営の審査を通過したものだけ
　団体アカウントは運営が実在を確認したうえで公開されます。

・スカウトは定型文のみ
　団体が学生に送れるメッセージは5種類の定型文に限定されています。自由に文章を書くことはできないため、不適切な勧誘や個人的な連絡が届くことはありません。

・通報とブロック
　気になる相手はいつでも通報・ブロックできます。ブロックした団体からはスカウトが届かなくなり、ブロックしたことは相手に通知されません。通報は受領から24時間以内に運営が確認します。

■ こんな人におすすめ
・入学したばかりで、どのサークルがあるのか分からない
・新歓の時期を逃してしまった
・自分から話しかけるのが苦手
・掛け持ちできる団体をもう一つ探している
・自分の団体に入ってくれる後輩を探している

■ 利用について
本アプリの利用には、同志社大学または同志社女子大学が発行するメールアドレスが必要です。
App内課金・広告はありません。
```
（約780字）

---

## 4. キーワード（100字以内・カンマ区切り・スペースを入れない）

```
サークル,学生団体,新歓,大学生,スカウト,ゼミ,部活,サークル探し,学生,イベント,マッチング,キャンパス,交流,新入生
```
（62字）

> ⚠️ **「同志社」をキーワードに入れていない。** 大学名は第三者の名称であり、Apple は
> 他者の商標・ブランド名をキーワードに使うことを制限している。説明文の中で
> 「利用条件として」言及するのは事実の記載なので問題になりにくいが、キーワード欄で
> 検索流入を取りにいくと 5.2.1（知的財産）で指摘される可能性がある。
> 大学から正式に許諾を得ている場合はその旨を審査メモに書いたうえで追加してよい。

---

## 5. URL

| 項目 | URL | 状態 |
|---|---|---|
| サポートURL（必須） | https://nishikawataishi.github.io/D-Hub/support.html | HTTP 200 確認済み |
| プライバシーポリシーURL（必須） | https://nishikawataishi.github.io/D-Hub/privacy-policy.html | HTTP 200 確認済み |
| マーケティングURL（任意） | https://www.d-hub-link.com | 公開済み |

> どちらも GitHub Pages で配信されている。このままでも審査は通るが、URL に
> GitHub のユーザー名が出るため、独自ドメイン配下（例
> `https://www.d-hub-link.com/privacy-policy`）に置き直したほうが自然に見える。
> なお `https://nishikawataishi.github.io/D-Hub/` のルートは 404 のままでよい
> （index を置いていないだけで、個別ページは配信されている）。

---

## 6. App Review Information（審査メモ）

審査担当者は日本語を読めるとは限らないため英語で書く。ここが弱いと
「アカウントを作れないのでレビューできない（Guideline 2.1）」で差し戻される。

**Sign-in required**: Yes
**Demo account**: 学生用・団体用の2アカウントを本番に投入済み。
**認証情報はこのファイルに書かないこと** — `docs/` は GitHub Pages で公開されている。
実際の ID とパスワードは `scripts/review_seed.js`（gitignore対象・ローカルのみ）を参照し、
App Store Connect のフォームに直接入力する。

> ⚠️ **審査通過後、審査用アカウントとデモデータは削除すること**
> （`node scripts/review_seed.js delete --yes-production`）。
> デモ団体は実在の学生からも一覧に見えている。

```
NOTES FOR REVIEW

1. Account restriction
D-Hub connects students with student clubs at Doshisha University and
Doshisha Women's College of Liberal Arts in Kyoto, Japan. Sign-up requires an
email address issued by these universities (@mail.doshisha.ac.jp,
@dwc.doshisha.ac.jp). Because reviewers cannot obtain such an address, please
use the demo accounts provided above. Both a student account and a club
(organization) account are provided so that both sides of the app can be
reviewed.

2. User-generated content (Guideline 1.2)
The app contains user-generated content: student profile photos and club
profiles. The following safeguards are implemented:
- Report: every profile, club page and scout message has a report action in
  the app bar. Reports are reviewed by the operator within 24 hours, as stated
  in Article 7 of the Terms of Use (viewable in-app from My Page).
- Block: users can block the other party from the same menu. Blocking is
  enforced server-side by Firestore Security Rules, not only in the UI.
- Message restriction: clubs cannot write free-form messages to students.
  Scout messages are limited to five fixed templates, and the values embedded
  in them are validated server-side against data the student actually
  registered. Free text from clubs to students is impossible by design.
- Club verification: club accounts are published only after the operator
  confirms that the club actually exists.
- Terms agreement: users must agree to the Terms of Use and Privacy Policy
  with an explicit checkbox before creating an account.

3. Account deletion (Guideline 5.1.1(v))
Both student and club accounts can be deleted in the app.
- Student: My Page (4th tab) > "退会する" (Delete account) at the bottom of
  the settings list.
- Club: Profile tab (4th tab) > "退会する" at the bottom of the form.
Deletion requires password re-authentication and removes the account
immediately.

4. No in-app purchase, no advertising, no tracking
The app has no paid content and does not use any advertising or analytics SDK.
```

---

## 7. App Privacy（ASC の「Appのプライバシー」設問への回答）

`ios/Runner/PrivacyInfo.xcprivacy` と**必ず一致させること**。食い違うと 5.1.1 で差し戻される。

**トラッキング**: 行わない（`NSPrivacyTracking = false`）
**第三者への提供**: なし
**すべての項目に共通**: 用途は「アプリの機能」／ユーザーにリンクされる／トラッキングには使用しない

| ASC カテゴリ | 項目 | 実体 |
|---|---|---|
| 連絡先情報 | メールアドレス | Firebase Auth のログインID |
| 連絡先情報 | 名前 | 学生の氏名・団体名 |
| 連絡先情報 | その他の連絡先情報 | 団体の Instagram / LINE URL |
| ユーザーコンテンツ | 写真またはビデオ | プロフィール写真・団体の活動写真 |
| ユーザーコンテンツ | カスタマーサポート | お問い合わせフォームの本文 |
| ユーザーコンテンツ | その他のユーザーコンテンツ | 団体の紹介文、通報の詳細 |
| 識別子 | ユーザーID | Firebase Auth の UID |
| その他のデータ | その他のデータ | 学部・学年・キャンパス・興味タグ |

**「収集していない」と答える主なもの**: 位置情報、連絡先（アドレス帳）、支払い情報、
健康・フィットネス、閲覧履歴、検索履歴、診断情報、購入履歴、広告データ。

---

## 8. 年齢レーティング設問への回答

レーティングは回答から自動算出されるので、ここでは回答方針を決めておく。

| 設問 | 回答 |
|---|---|
| 暴力・性的表現・薬物・ギャンブル等 | すべて「なし」 |
| ユーザー生成コンテンツの有無 | **あり**（プロフィール写真・団体紹介文） |
| UGC のモデレーション有無 | **あり**（通報・ブロック・団体審査・定型文制限） |
| 無制限のWebアクセス | なし（外部リンクは団体の Instagram / LINE への遷移のみ） |
| 出会い系・マッチング機能 | **要判断**（下記） |

> ⚠️ **「出会い系（Dating）」の設問には慎重に。** D-Hub は団体↔学生のスカウトであり
> 個人間のマッチングではない。恋愛目的の機能もない。したがって「なし」と回答するのが
> 実態に即しているが、アプリ名や説明文が「マッチング」を強調しすぎると審査で
> 出会い系として扱われ、年齢レーティングが上がる。説明文では「団体とつながる」
> 表現に統一してある。

---

## 9. 輸出コンプライアンス

`Info.plist` に `ITSAppUsesNonExemptEncryption = false` を設定済みのため、
アップロードのたびに暗号化に関する質問は表示されない。HTTPS のみを使用し、
独自の暗号化は実装していないため、この回答で正しい。

---

## 10. スクリーンショット構成案

**必須は iPhone 6.9インチ（1290 × 2796 px）1組のみ。** 6.5インチ以下は
6.9インチのものが自動で流用される。iPad は `TARGETED_DEVICE_FAMILY = 1`
（iPhone専用）のため不要。

最大10枚まで登録できるが、実際に見られるのは最初の3枚。左から順に:

| # | 画面 | 添えるキャッチコピー |
|---|---|---|
| 1 | スカウト受信一覧 | 待っているだけで、声がかかる |
| 2 | ホーム（団体一覧・検索） | 学内のサークルを、まとめて探す |
| 3 | 団体詳細 | 活動の雰囲気を、写真で確かめる |
| 4 | イベント一覧 | 新歓イベントを見逃さない |
| 5 | マイページ（プロフィール） | 興味を登録するだけ |
| 6 | 通報・ブロックのメニュー | 安心して使える仕組み |

6枚目を入れておくと、審査担当者が Guideline 1.2 の対応を掲載物からも確認できる。

撮影方法は `docs/store/02_screenshot_guide.md` を参照。
