import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio_pro_luxe/main.dart';

void main() {
  testWidgets('shows setup guidance when Supabase is not configured', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetupRequired()));
    expect(find.text('QR Studio Pro Luxe'), findsOneWidget);
    expect(find.textContaining('Supabase'), findsWidgets);
  });
}
