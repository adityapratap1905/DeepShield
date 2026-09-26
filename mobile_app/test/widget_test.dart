import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deepshield/core/services/storage_service.dart';
import 'package:deepshield/main.dart';

void main() {
  testWidgets('DeepShield app smoke test', (WidgetTester tester) async {
    // Initialize mock SharedPreferences for StorageService
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    
    // Build our app inside a ProviderScope
    await tester.pumpWidget(
      const ProviderScope(child: DeepShieldApp()),
    );

    // Just ensure it builds without throwing
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
