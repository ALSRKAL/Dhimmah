import 'package:dhimmah/core/files/document_save_channel.dart';
import 'package:dhimmah/core/files/file_gateway.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the restore picker asks Android for.
///
/// This is the fix for the defect where the picker opened and looked empty. The
/// filter is turned into an intent by `file_selector_android`, and inside that
/// plugin a non-empty list of types becomes `*/*` *plus* an `EXTRA_MIME_TYPES`
/// constraint — so a document whose provider reports a different type is hidden
/// even though it is right there on the device.
///
/// The filter is invisible from the outside once Android has answered, so the
/// test watches what the gateway asks for instead: a single group with no
/// extensions and no MIME types, which the plugin turns into an unrestricted
/// `*/*` with no constraint. Content validation remains the authority on whether
/// a chosen file is a backup at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the save destination', _documentChannelTests);

  test('the picker is asked for without a filter that could hide a backup', () async {
    List<XTypeGroup>? asked;
    String? sawPath;

    final PlatformFileGateway gateway = PlatformFileGateway(
      open: ({
        List<XTypeGroup>? acceptedTypeGroups,
        String? initialDirectory,
      }) async {
        asked = acceptedTypeGroups;
        return XFile('/tmp/a-backup.dhimmah');
      },
    );

    sawPath = await gateway.pickBackupFile();

    expect(sawPath, '/tmp/a-backup.dhimmah');
    expect(asked, hasLength(1), reason: 'one group, so one intent');
    final XTypeGroup group = asked!.single;
    expect(
      group.extensions,
      anyOf(isNull, isEmpty),
      reason: 'an extension list cannot be converted for `.dhimmah` and '
          'narrows the intent instead',
    );
    expect(
      group.mimeTypes,
      anyOf(isNull, isEmpty),
      reason: 'a MIME list adds an EXTRA_MIME_TYPES constraint, and a provider '
          'that reports another type would hide the file',
    );
  });

  test('a cancelled picker is no file, not an error', () async {
    final PlatformFileGateway gateway = PlatformFileGateway(
      open: ({List<XTypeGroup>? acceptedTypeGroups, String? initialDirectory}) async =>
          null,
    );
    expect(await gateway.pickBackupFile(), isNull);
  });

  test('the remembered folder is offered to the picker as where to start', () async {
    String? sawInitial;
    final PlatformFileGateway gateway = PlatformFileGateway(
      open: ({
        List<XTypeGroup>? acceptedTypeGroups,
        String? initialDirectory,
      }) async {
        sawInitial = initialDirectory;
        return null;
      },
    );

    // A hint, not an instruction: the plugin turns it into
    // `EXTRA_INITIAL_URI`, and a provider that ignores it still leaves the user
    // a working picker. It is never allowed to become a path the app opens.
    await gateway.pickBackupFile(initialDirectory: 'content://test/dhimmah-backups');

    expect(sawInitial, 'content://test/dhimmah-backups');
  });

  test('with no folder configured, the picker is asked for no starting point',
      () async {
    String? sawInitial;
    final PlatformFileGateway gateway = PlatformFileGateway(
      open: ({
        List<XTypeGroup>? acceptedTypeGroups,
        String? initialDirectory,
      }) async {
        sawInitial = initialDirectory;
        return null;
      },
    );

    await gateway.pickBackupFile();

    expect(sawInitial, isNull);
  });

  test('the name a user sees is the file name, not the path', () {
    expect(backupFileName('/data/user/0/app/files/x.dhimmah'), 'x.dhimmah');
    expect(backupFileName('x.dhimmah'), 'x.dhimmah');
    expect(backupExtension, 'dhimmah');
  });
}

/// The document chooser and the content operations behind it.
///
/// Nothing above the gateway may know that a saved document is a `content://`
/// URI rather than a path, so the gateway is where that is checked: the channel
/// is mocked the way Flutter mocks channels, and the identifier stays opaque.
void _documentChannelTests() {
  const MethodChannel channel = MethodChannel(DocumentSaveChannel.methodChannelName);
  final List<MethodCall> calls = <MethodCall>[];

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a chosen document becomes a save target, and nothing else changes', () async {
    answer((MethodCall call) async => <String, Object?>{
          'uri': 'content://provider/doc%2F1',
          'displayName': 'نسختي.dhimmah',
          'size': 4096,
        });

    final SaveTarget? target =
        await const PlatformFileGateway().createSaveTarget(suggestedName: 'x.dhimmah');

    expect(target, isNotNull);
    expect(target!.displayName, 'نسختي.dhimmah');
    expect(target.identifier, 'content://provider/doc%2F1');
    expect(calls.single.method, 'createDocument');
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['name'],
      'x.dhimmah',
      reason: 'the name the platform is asked for is the one suggested',
    );
  });

  test('backing out of the chooser is null, not an error', () async {
    answer((MethodCall call) async => null);
    expect(
      await const PlatformFileGateway().createSaveTarget(suggestedName: 'x.dhimmah'),
      isNull,
    );
  });

  test('an empty document is refused by the platform and named as such', () async {
    answer((MethodCall call) async {
      throw PlatformException(code: 'empty_bytes', message: 'refusing to write');
    });
    await expectLater(
      const PlatformFileGateway()
          .createSaveTarget(suggestedName: 'x.dhimmah')
          .then((SaveTarget? target) => target!.write(const <int>[])),
      throwsA(
        isA<DocumentException>().having(
          (DocumentException e) => e.failure,
          'failure',
          DocumentFailure.empty,
        ),
      ),
    );
  });

  test('a missing platform names itself rather than looking like a bad file', () async {
    answer((MethodCall call) async {
      throw MissingPluginException('no channel');
    });
    await expectLater(
      const PlatformFileGateway().createSaveTarget(suggestedName: 'x.dhimmah'),
      throwsA(
        isA<DocumentException>().having(
          (DocumentException e) => e.failure,
          'failure',
          DocumentFailure.unavailable,
        ),
      ),
    );
  });

  test('the suggested type is one every provider accepts', () {
    // `.dhimmah` has no registered type anywhere; a made-up
    // `application/vnd.dhimmah` is refused by providers that do not know it,
    // which is the mistake that made the restore picker look empty.
    expect(DocumentSaveChannel.mimeType, 'application/octet-stream');
    expect(
      DocumentSaveChannel.methodChannelName,
      'dhimmah/backup_file',
      reason: 'the Kotlin side registers this exact name; android_setup_test '
          'pins the two together',
    );
  });
}
