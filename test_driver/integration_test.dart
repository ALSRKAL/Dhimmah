import 'package:integration_test/integration_test_driver.dart';

/// The driver half of the frame measurement.
///
/// `flutter test integration_test/...` runs in debug, where the numbers are the
/// JIT's, not the engine's. This is what runs the same test in profile:
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/frame_measure_test.dart --profile -d device
Future<void> main() => integrationDriver();
