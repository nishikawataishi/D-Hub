#!/usr/bin/env bash
#
# iOS 配布署名資材の作成ツール（Windows / Git Bash で動く）
#
# Mac が無くても App Store 配布用の証明書は作れる。Xcode の「証明書アシスタント」が
# やっているのは CSR の生成と .p12 への詰め直しだけで、どちらも openssl でできる。
#
# ── 使い方（この順番で） ──
#
#   1) ./tools/ios-signing-bootstrap.sh csr
#        秘密鍵と CSR を ios/certs/ に作る。
#
#   2) https://developer.apple.com/account/resources/certificates/list
#        ＋ → Apple Distribution → 手順1の dist.csr をアップロード → .cer をダウンロード
#
#   3) ./tools/ios-signing-bootstrap.sh p12 ~/Downloads/distribution.cer
#        .cer と手順1の秘密鍵を .p12 にまとめる。パスワードは自動生成して表示する。
#
#   4) https://developer.apple.com/account/resources/profiles/list
#        ＋ → App Store Connect → App ID: com.dhublink.app → 手順2の証明書を選択
#        → .mobileprovision をダウンロード
#
#   5) ./tools/ios-signing-bootstrap.sh secrets ~/Downloads/D_Hub_App_Store.mobileprovision
#        GitHub Secrets に貼る値をすべて出力する。
#
# ios/certs/ は .gitignore 済み。中身は絶対にコミットしない。

set -euo pipefail

# ── Git Bash (MSYS) のパス変換について ──
# MSYS は POSIX 風パス "/c/Users/..." をネイティブ Windows バイナリに渡すとき
# "C:\Users\..." へ変換する。openssl は Windows ネイティブなのでこの変換が必須。
# 一方で "/CN=..." のような引数も「パスだ」と誤認して壊してしまう。
#
# MSYS_NO_PATHCONV=1 で変換を止めると -subj は守れるが、今度はファイルパスが
# 解決できなくなる（両立しない）。そこで -subj を使わず、証明書の subject は
# 一時的な openssl 設定ファイルで渡す。これなら変換を無効化する必要がなく、
# macOS / Linux でも同じ挙動になる。

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$REPO_ROOT/ios/certs"

KEY="$CERT_DIR/dist.key"
CSR="$CERT_DIR/dist.csr"
P12="$CERT_DIR/distribution.p12"
P12_PASS_FILE="$CERT_DIR/distribution.p12.password"

BUNDLE_ID="com.dhublink.app"

die()  { printf '\033[31mエラー: %s\033[0m\n' "$1" >&2; exit 1; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$1"; }
info() { printf '\033[36m%s\033[0m\n' "$1"; }

need_openssl() {
  command -v openssl >/dev/null 2>&1 || die "openssl が見つからない。Git Bash から実行しているか確認しろ。"
}

# base64 を1行で出力する。GNU/BSD の base64 は -w の有無が環境で違うため
# openssl に統一する（-A で改行なし）。
b64() { openssl base64 -A -in "$1"; }

# ─────────────────────────── csr ───────────────────────────
cmd_csr() {
  need_openssl
  mkdir -p "$CERT_DIR"

  if [ -f "$KEY" ]; then
    die "$KEY が既に存在する。作り直すなら先に ios/certs/ を退避しろ。
（この鍵を失うと、対応する証明書は二度と使えなくなる）"
  fi

  info "Apple Distribution 証明書用の秘密鍵と CSR を作る。"

  # 引数で渡せば非対話で動く: csr "<氏名>" "<メールアドレス>"
  local CN="${1:-}" EMAIL="${2:-}"
  [ -n "$CN" ]    || read -r -p "  氏名（証明書の Common Name / 例: Taishi Nishikawa）: " CN
  [ -n "$EMAIL" ] || read -r -p "  メールアドレス: " EMAIL
  [ -n "$CN" ]    || die "氏名は必須。"
  [ -n "$EMAIL" ] || die "メールアドレスは必須。"

  # CSR の subject は Apple が証明書発行時に
  # "Apple Distribution: <氏名> (<TeamID>)" へ書き換えるため、ここの値は控え用。

  # Apple の要件: RSA 2048bit / SHA-256
  openssl genrsa -out "$KEY" 2048
  chmod 600 "$KEY" 2>/dev/null || true

  # subject は -subj ではなく設定ファイルで渡す（冒頭のコメント参照）
  local cfg="$CERT_DIR/.csr.cnf"
  cat > "$cfg" <<EOF
[req]
prompt             = no
default_md         = sha256
distinguished_name = dn

[dn]
emailAddress = $EMAIL
CN           = $CN
C            = JP
EOF

  openssl req -new -key "$KEY" -out "$CSR" -config "$cfg"
  rm -f "$cfg"

  ok "秘密鍵: $KEY"
  ok "CSR   : $CSR"
  echo
  info "次の手順:"
  echo "  1. https://developer.apple.com/account/resources/certificates/list を開く"
  echo "  2. ＋ ボタン → 「Apple Distribution」を選ぶ"
  echo "  3. Choose File で $CSR をアップロード"
  echo "  4. 発行された .cer をダウンロード"
  echo "  5. ./tools/ios-signing-bootstrap.sh p12 <ダウンロードした.cer>"
  echo
  info "$KEY は絶対に消すな。これを失うと証明書を作り直すことになる。"
}

# ─────────────────────────── p12 ───────────────────────────
cmd_p12() {
  need_openssl
  local cer="${1:-}"
  [ -n "$cer" ]   || die "使い方: $0 p12 <Appleからダウンロードした.cer>"
  [ -f "$cer" ]   || die "ファイルが無い: $cer"
  [ -f "$KEY" ]   || die "$KEY が無い。先に '$0 csr' を実行しろ。"

  mkdir -p "$CERT_DIR"
  local pem="$CERT_DIR/distribution.pem"

  # Apple が配る .cer は DER 形式。PEM に変換する。
  if ! openssl x509 -inform DER -in "$cer" -out "$pem" 2>/dev/null; then
    # 既に PEM の場合もあるので念のため試す
    openssl x509 -inform PEM -in "$cer" -out "$pem" 2>/dev/null \
      || die "$cer を証明書として読めない。ダウンロードし直せ。"
  fi

  # 秘密鍵と証明書が本当に対になっているかを確認する。
  # ここが食い違うと xcodebuild は「該当する署名 ID が無い」としか言わず原因が掴めない。
  local key_mod cert_mod
  key_mod="$(openssl rsa  -noout -modulus -in "$KEY" | openssl sha256)"
  cert_mod="$(openssl x509 -noout -modulus -in "$pem" | openssl sha256)"
  [ "$key_mod" = "$cert_mod" ] \
    || die "秘密鍵と証明書が対応していない。
この .cer は別の CSR から発行されたものだ。$CSR をアップロードして発行し直せ。"
  ok "秘密鍵と証明書の対応を確認"

  local subject not_after
  subject="$(openssl x509 -noout -subject -in "$pem")"
  not_after="$(openssl x509 -noout -enddate -in "$pem" | sed 's/notAfter=//')"

  # 配布用証明書かどうかを見る。Development だと TestFlight に出せない。
  if echo "$subject" | grep -qi "Development"; then
    die "これは Development 証明書だ。「Apple Distribution」で発行し直せ。
subject: $subject"
  fi

  local password
  password="$(openssl rand -hex 20)"

  # macOS の security import が確実に読めるよう、旧来の PBE(3DES/SHA1)で書き出す。
  # OpenSSL 3 の既定(AES-256/SHA-256)はキーチェーンへの取り込みで弾かれることがある。
  openssl pkcs12 -export \
    -inkey "$KEY" -in "$pem" \
    -name "Apple Distribution (D-Hub)" \
    -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
    -passout "pass:$password" \
    -out "$P12"

  # 書き出した .p12 を読み戻せるか検証する（パスワード込みで往復確認）
  openssl pkcs12 -in "$P12" -passin "pass:$password" -nokeys -noout 2>/dev/null \
    || die ".p12 を作ったが読み戻せない。openssl のバージョンを確認しろ。"
  ok ".p12 の読み戻し検証 OK"

  printf '%s' "$password" > "$P12_PASS_FILE"
  chmod 600 "$P12_PASS_FILE" 2>/dev/null || true
  rm -f "$pem"

  echo
  ok "証明書   : $P12"
  ok "パスワード: $P12_PASS_FILE に保存した"
  info "  subject : $subject"
  info "  有効期限: $not_after"
  echo
  info "次の手順:"
  echo "  1. https://developer.apple.com/account/resources/identifiers/list で"
  echo "     App ID '$BUNDLE_ID' を登録（未登録なら）"
  echo "  2. https://developer.apple.com/account/resources/profiles/list を開く"
  echo "  3. ＋ → Distribution の「App Store Connect」→ App ID: $BUNDLE_ID"
  echo "     → いま作った証明書を選択 → 名前を付けて .mobileprovision をダウンロード"
  echo "  4. ./tools/ios-signing-bootstrap.sh secrets <ダウンロードした.mobileprovision>"
}

# ───────────────────────── secrets ─────────────────────────
cmd_secrets() {
  need_openssl
  local profile="${1:-}"
  [ -n "$profile" ] || die "使い方: $0 secrets <.mobileprovision>"
  [ -f "$profile" ] || die "ファイルが無い: $profile"
  [ -f "$P12" ]     || die "$P12 が無い。先に '$0 p12 <.cer>' を実行しろ。"
  [ -f "$P12_PASS_FILE" ] || die "$P12_PASS_FILE が無い。"

  # .mobileprovision は CMS 署名された plist。openssl で中身を取り出せる
  # （security コマンドは macOS 専用なので使えない）。
  local plist
  plist="$(openssl cms -inform DER -verify -noverify -in "$profile" 2>/dev/null)" \
    || die "$profile を .mobileprovision として読めない。"

  # キーの直後の最初の <string> を取る。TeamIdentifier のように
  # 値が <array> でラップされているキーがあるため、次の1行だけを見てはいけない。
  extract() { printf '%s' "$plist" | grep -A3 "<key>$1</key>" | grep -m1 '<string>' \
              | sed -e 's/.*<string>//' -e 's|</string>.*||' -e 's/^[[:space:]]*//'; }

  local pname team appid
  pname="$(extract Name)"
  team="$(extract TeamIdentifier)"
  appid="$(extract application-identifier)"

  # App Store 用プロファイルには端末リストが無い
  if printf '%s' "$plist" | grep -q "ProvisionedDevices"; then
    die "これは Development / Ad Hoc プロファイルだ（端末が登録されている）。
Distribution の「App Store Connect」で作り直せ。"
  fi
  ok "App Store 配布用プロファイルであることを確認"

  [ "$appid" = "$team.$BUNDLE_ID" ] \
    || die "プロファイルの Application ID が想定と違う。
  期待: $team.$BUNDLE_ID
  実際: $appid"
  ok "Bundle ID の一致を確認: $BUNDLE_ID"

  echo
  info "═══ GitHub Secrets に登録する値 ═══"
  info "  Settings → Secrets and variables → Actions → New repository secret"
  echo
  echo "── APPLE_TEAM_ID ──"
  echo "$team"
  echo
  echo "── IOS_DIST_CERT_PASSWORD ──"
  cat "$P12_PASS_FILE"; echo
  echo
  echo "── IOS_DIST_CERT_P12_BASE64 ──"
  b64 "$P12"; echo
  echo
  echo "── IOS_PROVISIONING_PROFILE_BASE64 ──"
  b64 "$profile"; echo
  echo
  info "═══ 別途 App Store Connect で取得して登録するもの ═══"
  echo "  ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8_BASE64"
  echo "  App Store Connect → ユーザとアクセス → 統合 → App Store Connect API"
  echo "  でキーを作成（アクセス権は App Manager 以上）。.p8 は一度しか"
  echo "  ダウンロードできないので必ず保存すること。"
  echo "  base64 化: ./tools/ios-signing-bootstrap.sh b64 ~/Downloads/AuthKey_XXXXXXXX.p8"
  echo
  info "プロファイル名（参考・Secret 登録は不要。CI が自動で読む）: $pname"
}

# ─────────────────────────── b64 ───────────────────────────
cmd_b64() {
  need_openssl
  local f="${1:-}"
  [ -n "$f" ] || die "使い方: $0 b64 <ファイル>"
  [ -f "$f" ] || die "ファイルが無い: $f"
  b64 "$f"; echo
}

usage() {
  sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

case "${1:-}" in
  csr)     shift; cmd_csr "$@" ;;
  p12)     shift; cmd_p12 "$@" ;;
  secrets) shift; cmd_secrets "$@" ;;
  b64)     shift; cmd_b64 "$@" ;;
  *)       usage ;;
esac
