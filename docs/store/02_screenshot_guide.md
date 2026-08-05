# スクリーンショット撮影手順（Mac 不要）

App Store が要求する **iPhone 6.9インチ = 1290 × 2796 px** のスクリーンショットを、
Windows だけで撮る手順。実機も Xcode も シミュレータも要らない。

## 仕組み

本番の Flutter Web（https://d-hub-link.com）を、Chrome の DevTools Protocol で
**430 × 932 CSS px / deviceScaleFactor 3** にエミュレートして撮影する。
430×932 は iPhone 16 Pro Max の論理解像度で、3倍すると 1290×2796 ちょうどになる。

Flutter Web と iOS ネイティブは同じ Dart コードから同じウィジェットを描くため、
ここで撮れる絵は実機とほぼ同一になる。

> Chrome の `--screenshot` フラグ単体では**撮れない**。`--virtual-time-budget` が
> Flutter のフレームループを止めてしまい、真っ白な画像になる。必ず CDP 経由で
> 「実時間で待ってから」撮ること。

## 手順

### 1. Chrome を CDP 付きで起動

```bash
SP=/c/tmp/dhub-shots   # 作業用ディレクトリ（どこでもよい）
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --headless=new \
  --remote-debugging-port=9222 \
  --user-data-dir="$SP/chromeprofile" \
  --hide-scrollbars --no-first-run --disable-extensions \
  about:blank &
```

### 2. ログインして撮る

`tools/screenshots/cdp.mjs` が CDP の最小ドライバ。コマンドを引数に並べると順に実行する。
Flutter Web は canvas に描画するので DOM セレクタは使えない。**座標クリック**で操作する。
座標は CSS px（430 × 932 の座標系）で指定する。

```bash
# ログイン画面を出す
node tools/screenshots/cdp.mjs "goto:https://d-hub-link.com/" "wait:12000" "shot:$SP/login.png"

# メール・パスワードを入れてログイン
node tools/screenshots/cdp.mjs \
  "click:215,489" "wait:400" "type:<審査用アカウントのメール>" \
  "click:215,553" "wait:400" "type:<パスワード>" \
  "click:215,631" "wait:9000" "shot:$SP/home.png"

# 下タブを移動しながら撮る（ホーム57 / スカウト164 / イベント270 / マイページ375、y=880）
node tools/screenshots/cdp.mjs \
  "click:164,880" "wait:5000" "shot:$SP/scout.png" \
  "click:270,880" "wait:5000" "shot:$SP/event.png" \
  "click:375,880" "wait:5000" "shot:$SP/mypage.png"

# 団体詳細 → 通報・ブロックメニュー
node tools/screenshots/cdp.mjs \
  "click:57,880" "wait:4000" "click:110,330" "wait:5000" "shot:$SP/org.png" \
  "click:409,29" "wait:2500" "shot:$SP/moderation.png"
```

コマンド一覧: `goto:<url>` / `wait:<ms>` / `click:<x>,<y>` / `type:<text>` /
`key:<Enter|Tab>` / `shot:<path>` / `eval:<js>`

### 3. サイズを確認

```bash
python -c "from PIL import Image; print(Image.open('login.png').size)"
# → (1290, 2796)
```

座標を探すときは 1/3 に縮小して見るとよい（縮小後の座標がそのまま CSS px になる）。

```bash
python -c "from PIL import Image; im=Image.open('home.png'); im.resize((im.width//3,im.height//3)).save('home_small.png')"
```

## 撮影済みのもの

`docs/store/screenshots/` に 2026-08-05 時点のものが入っている（すべて 1290×2796）。

| ファイル | 画面 |
|---|---|
| `00_login.png` | ログイン |
| `01_scout.png` | スカウト受信一覧 |
| `02_home.png` | ホーム（団体一覧・検索） |
| `03_org_detail.png` | 団体詳細 |
| `04_event.png` | イベント一覧 |
| `05_mypage.png` | マイページ |
| `06_moderation.png` | 通報・ブロックのメニュー |

## ⚠️ そのまま App Store に出せない理由

現在の本番データは**審査用のデモデータ**であり、団体名に `【デモ】` が付き、
紹介文も「ストア審査のために用意した架空の団体で、実在しません。」になっている。
イベントに至っては「実際には開催されません。」と書かれている。

審査は通るが、**掲載物としては明らかに見栄えが悪い**。出す前にどちらかを決める必要がある。

1. **スクショ用の見せ札データを用意する** — `scripts/review_seed.js` に、`【デモ】` を
   付けない自然な団体名・紹介文・イベントを入れるモードを足して撮り直す。
   審査通過後に消せばよいので、実在の個人情報を一切使わずに済む。**推奨。**
2. **実データで撮る** — 実在の団体名・活動写真、学生検索画面なら学生の顔写真が
   App Store 上で公開されることになる。**団体および学生本人の許諾が必須**であり、
   許諾なしにやってはいけない。

なお学生検索画面（団体アカウント側）は、実データで撮ると学生の顔写真がそのまま
公開されるため、選択肢 1 以外では撮らないこと。
