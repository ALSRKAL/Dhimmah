import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_fixture.dart';

/// Writes a populated database to a file, for reviewing the app's screens with
/// real data in them. Not part of the normal test run.
///
/// The dataset itself lives in `test/support/store_demo_seed.dart`, shared with
/// the store-capture integration test so both photograph the same ledger. The
/// writing — including the copy in the shape of the previous schema — lives in
/// `test/support/legacy_fixture.dart`, shared with the backward-compatibility
/// test so that test never depends on this one having run.
///
///   flutter test test/tool/seed_demo_data_test.dart
///   adb push build/demo/dhimmah.sqlite /data/local/tmp/
///
void main() {
  test('writes a demo database', () async {
    final DemoDatabases written = await writeDemoDatabases(
      Directory('build/demo'),
    );
    // ignore: avoid_print
    print('SEEDED ${written.current.path}');
    // ignore: avoid_print
    print('SEEDED ${written.legacy.path} (as version 2)');
  });
}
