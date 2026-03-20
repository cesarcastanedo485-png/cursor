import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/core/app_strings.dart';
import 'package:mordechaius_maximus/screens/capabilities/capabilities_screen.dart';

void main() {
  testWidgets('CapabilitiesScreen shows Tools and Instruction manual tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CapabilitiesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Instruction manual'), findsOneWidget);
    expect(find.text(AppStrings.capabilities), findsOneWidget);
  });

  testWidgets('Tools tab shows capability cards with Test, Manual, Configure buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CapabilitiesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ListView.builder builds only visible items; first capability (Send SMS) is visible
    expect(find.text('Send SMS'), findsOneWidget);
    expect(find.text('Test'), findsWidgets);
    expect(find.text('Manual'), findsWidgets);
    expect(find.text('Configure'), findsWidgets);
  });

  testWidgets('Tapping Manual opens bottom sheet with steps', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CapabilitiesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manual').first);
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Send SMS'), findsWidgets);
  });
}
