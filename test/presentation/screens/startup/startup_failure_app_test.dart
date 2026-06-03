import 'package:epos_app/presentation/screens/startup/startup_failure_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a controlled database migration failure message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const StartupFailureApp.databaseMigrationFailure(
        databasePath: r'C:\Users\cashier\Documents\epos.sqlite',
        backupDirectoryPath: r'C:\Users\cashier\Documents\backups',
      ),
    );

    expect(find.text('Database update failed'), findsOneWidget);
    expect(find.textContaining('could not be upgraded safely'), findsOneWidget);
    expect(
      find.textContaining('was not modified by the installer'),
      findsOneWidget,
    );
    expect(find.textContaining('restore from backup'), findsOneWidget);
    expect(
      find.textContaining(r'C:\Users\cashier\Documents\epos.sqlite'),
      findsOneWidget,
    );
    expect(
      find.textContaining(r'C:\Users\cashier\Documents\backups'),
      findsOneWidget,
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
