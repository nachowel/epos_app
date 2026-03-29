import 'package:drift/native.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epos_app/app.dart';
import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart';

void main() {
  testWidgets('App boots with login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      EposApp(
        database: AppDatabase(NativeDatabase.memory()),
        appConfig: AppConfig.fromValues(
          environment: 'test',
          appVersion: 'test',
        ),
        appLogger: const NoopAppLogger(),
        sharedPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginTitle), findsOneWidget);
  });
}
