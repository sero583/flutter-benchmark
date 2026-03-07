/// Smoke test for the Flutter Renderer Benchmark Suite.
///
/// Verifies that the app launches and renders the home page header.
library;

import "package:flutter_test/flutter_test.dart";

import "package:flutter_benchmark/main.dart";

void main() {
  testWidgets("BenchmarkApp renders home page", (WidgetTester tester) async {
    await tester.pumpWidget(const BenchmarkApp());
    await tester.pumpAndSettle();

    // The header should show the app title.
    expect(find.text("Flutter Renderer Benchmark Suite"), findsOneWidget);

    // At least one benchmark card should be visible.
    expect(find.text("Particle Storm"), findsOneWidget);
  });
}
