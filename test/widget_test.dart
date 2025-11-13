import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zy/main.dart';

void main() {
  testWidgets('Builds grid with Apple icons', (WidgetTester tester) async {
    await tester.pumpWidget(const AppleIconSortApp());
    expect(find.byType(AppleIconTile), findsWidgets);
  });
}
