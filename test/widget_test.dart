import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf_viewer/main.dart'; // ✅ match your pubspec.yaml name

void main() {
  testWidgets('Mega PDF Viewer loads and displays basic widgets',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MegaPdfViewerApp());

    expect(find.text('Mega PDF Viewer'), findsOneWidget);

    expect(find.byIcon(Icons.file_open), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_add), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks), findsOneWidget);
    expect(find.byIcon(Icons.brightness_6), findsOneWidget);
    expect(find.byIcon(Icons.input), findsOneWidget);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
  });
}
