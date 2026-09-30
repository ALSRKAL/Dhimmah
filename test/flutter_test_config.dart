import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone every test runs on, unless the test says otherwise.
///
/// Dhimmah follows the phone's language, and the test engine reports an
/// American English phone. The suite reads — and most of its assertions are
/// written — in Arabic, the language of the people the app is for, so every
/// test starts on an Arabic phone and a test about any other phone says so by
/// setting `tester.platformDispatcher.localesTestValue` itself.
///
/// Reset before each test rather than once, because the test binding keeps a
/// test value until something clears it: a test that moved the phone to English
/// would otherwise hand English to the next one.
const List<Locale> testDeviceLocales = <Locale>[Locale('ar', 'YE')];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.platformDispatcher.localesTestValue = testDeviceLocales);
  await testMain();
}
