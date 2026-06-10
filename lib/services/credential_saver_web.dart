/// Credential Management API ヘルパー（Web用実装）
///
/// web/index.html で定義された window.saveCredential を呼び出し、
/// Safari等にパスワード保存ダイアログを表示させる。
library;

import 'dart:js_interop';

@JS('saveCredential')
external void _saveCredential(JSString id, JSString password);

void saveCredential(String email, String password) {
  _saveCredential(email.toJS, password.toJS);
}
