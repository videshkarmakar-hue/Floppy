import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:floppy/main.dart';
import 'package:floppy/providers/file_manager_provider.dart';
import 'package:floppy/providers/media_provider.dart';

void main() {
  testWidgets('FloppyApp initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FileManagerProvider()),
          ChangeNotifierProvider(create: (_) => MediaProvider()),
        ],
        child: const FloppyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
