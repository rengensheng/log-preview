import 'package:flutter_test/flutter_test.dart';

import 'package:log_preview/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const LogPreviewApp());
    expect(find.text('日志查看器'), findsOneWidget);
    expect(find.text('选择日志文件'), findsOneWidget);
  });
}
