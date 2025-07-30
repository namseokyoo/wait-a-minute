import 'package:flutter_test/flutter_test.dart';
import 'package:wait_a_minute/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WaitAMinuteApp(firebaseReady: false));

    // Verify that permission screen is shown
    expect(find.text('Wait A Minute'), findsOneWidget);
    expect(find.text('고객 대기 감지 시스템'), findsOneWidget);
  });

  testWidgets('Permission screen shows permission items', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const WaitAMinuteApp(firebaseReady: false));
    
    // Wait a bit for widgets to render
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify permission items are shown (should be visible immediately)
    expect(find.text('카메라 권한'), findsOneWidget);
    expect(find.text('푸시 알림 권한'), findsOneWidget);
  });
}