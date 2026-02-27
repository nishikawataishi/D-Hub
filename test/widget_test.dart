import 'package:flutter_test/flutter_test.dart';
import 'package:d_scout/main.dart';

void main() {
  testWidgets('D.scout アプリが正常に起動する', (WidgetTester tester) async {
    // アプリをビルド
    await tester.pumpWidget(const DScoutApp());

    // ログイン画面が表示されることを確認
    expect(find.text('D.scout'), findsOneWidget);
    expect(find.text('大学メールアドレス'), findsOneWidget);
  });
}
