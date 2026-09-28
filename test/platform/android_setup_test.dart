import 'dart:io';

import 'package:dhimmah/core/files/document_save_channel.dart';
import 'package:dhimmah/core/security/biometric_service.dart';
import 'package:dhimmah/data/services/play_app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

/// Platform configuration that no Dart test can otherwise see.
///
/// Both of these were wrong in a build that shipped: the manifest permission was
/// present but the activity was a `FlutterActivity`, so every biometric prompt
/// was refused by `androidx.biometric` before it could be shown. The Dart code
/// was correct, the analyser was clean, and the only symptom was a fingerprint
/// button that did nothing — which is why the fix is pinned here.
void main() {
  final File activity = File(
    'android/app/src/main/kotlin/com/dhimmah/dhimmah/MainActivity.kt',
  );

  group('Android setup', () {

    test('the activity can host a biometric prompt', () {
      expect(
        activity.existsSync(),
        isTrue,
        reason: 'MainActivity.kt has moved; update this test with it',
      );
      final String source = activity.readAsStringSync();

      // `androidx.biometric` shows its prompt through a fragment and refuses to
      // run otherwise: local_auth_android returns NOT_FRAGMENT_ACTIVITY, which
      // surfaces as LocalAuthExceptionCode.uiUnavailable. Nothing in Dart
      // reveals this, so it is asserted from the declaration itself.
      expect(
        source,
        contains('FlutterFragmentActivity'),
        reason: 'MainActivity must extend FlutterFragmentActivity, not '
            'FlutterActivity, or every biometric prompt is refused',
      );
      expect(
        source,
        isNot(contains('FlutterActivity()')),
        reason: 'a bare FlutterActivity cannot host the biometric prompt',
      );
    });

    test('the biometric permission is declared', () {
      final String manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifest,
        contains('android.permission.USE_BIOMETRIC'),
        reason: 'local_auth needs USE_BIOMETRIC to reach the sensor',
      );
    });

    test('each channel is built once, so caller and callback are one object', () {
      // `FlutterActivity.onCreate` calls `delegate.onAttach` inside
      // `super.onCreate`, and that is what reaches `configureFlutterEngine` — so
      // the engine wiring happens *before* this activity's own `onCreate` body.
      // A field assigned in both places ends up holding one object while the
      // method channel answers through another, and the activity-result callback
      // is then delivered to an object that never asked for it: the Dart future
      // never completes, the screen sits on "جارٍ فحص المجلد" for ever, and the
      // URI grant the user just gave is left unclaimed. Counting the
      // construction sites is the shape of that mistake; reading the channel
      // through a nullable field inside the callback is the other half of it,
      // because `?.` turns "the wrong object" into "silently nothing".
      final String source = activity.readAsStringSync();
      for (final String channel in <String>[
        'AppUpdateChannel',
        'BackupFileChannel',
      ]) {
        expect(
          RegExp('$channel\\(this,').allMatches(source).length,
          1,
          reason: '$channel must be constructed exactly once; a second site '
              'means the method channel and the activity-result callback are '
              'different objects, and every result they deliver is dropped',
        );
      }
      for (final String dropped in <String>[
        'updateChannel?.onActivityResult',
        'backupFileChannel?.onDocumentCreated',
        'backupFileChannel?.onFolderChosen',
      ]) {
        expect(
          source,
          isNot(contains(dropped)),
          reason: '$dropped loses the result whenever the field is not the '
              'registered instance, which is exactly when it matters',
        );
      }
    });
  });

  group('the backup folder identifier', () {
    final File channel = File(
      'android/app/src/main/kotlin/com/dhimmah/dhimmah/BackupFileChannel.kt',
    );

    /// What the app stored on the Note 20 Ultra after the user granted
    /// `Documents` and the app created its subfolder inside it.
    const String stored =
        'content://com.android.externalstorage.documents'
        '/tree/primary%3ADocuments'
        '/document/primary%3ADocuments%2FDhimmah%20Backups';

    test('a folder inside a granted tree carries both segments', () {
      // This is the fact the shipped code got wrong, and it is about the input
      // rather than about the code: a URI built under a tree answers "yes" to
      // *contains* `tree`, so a resolver that asks that question first takes the
      // tree's own id — the parent — and every write lands one level up while
      // the app reports the folder it was told about. Asserting the shape here
      // means the reason for the rule below cannot be quietly forgotten.
      expect(stored.split('/'), contains('tree'));
      expect(stored.split('/'), contains('document'));
      // A bare grant, for contrast, carries only the tree segment.
      const String bareTree =
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments';
      expect(bareTree.split('/'), contains('tree'));
      expect(bareTree.split('/'), isNot(contains('document')));
    });

    test('the document segment decides, and is tested for first', () {
      final String source = channel.readAsStringSync();
      final int start = source.indexOf('private fun folderDocumentId');
      expect(start, greaterThan(0), reason: 'folderDocumentId has moved');
      final String body = source.substring(
        start,
        source.indexOf('\n    }', start),
      );
      final int documentAt = body.indexOf('DOCUMENT_SEGMENT');
      final int treeAt = body.indexOf('TREE_SEGMENT');
      expect(
        documentAt,
        greaterThan(0),
        reason: 'folderDocumentId must decide on the document segment',
      );
      expect(
        documentAt,
        lessThan(treeAt),
        reason: 'the document test has to come first: a URI under a tree has '
            'both segments, so testing for the tree first resolves to the '
            "folder's parent and writes the backup beside it",
      );
      expect(
        body,
        contains('getDocumentId'),
        reason: 'a document URI names the folder itself',
      );
      expect(
        body,
        contains('getTreeDocumentId'),
        reason: 'a bare grant has to be asked for its tree id',
      );
      // The constants must still be the two real segments.
      expect(source, contains('TREE_SEGMENT = "tree"'));
      expect(source, contains('DOCUMENT_SEGMENT = "document"'));
    });

    test('the folder is adopted when it is already there, not made again', () {
      // Android's own storage provider does not refuse a duplicate directory
      // name: asked for `Dhimmah Backups` in a folder that already has one it
      // creates `Dhimmah Backups (1)`. A reinstall followed by re-picking the
      // same folder — the moment the user most needs their backups — then landed
      // in an empty new folder beside six real copies, and the app said "no
      // backups in this folder" while nothing errored. The lookup has to come
      // first, and it has to be a lookup for a *folder*.
      final String source = channel.readAsStringSync();
      final int start = source.indexOf('private fun createFolder');
      expect(start, greaterThan(0), reason: 'createFolder has moved');
      final String body = source.substring(
        start,
        source.indexOf('\n    }', start),
      );
      final int lookAt = body.indexOf('findChildByName');
      final int createAt = body.indexOf('DocumentsContract.createDocument');
      expect(
        lookAt,
        greaterThan(0),
        reason: 'createFolder must look for an existing folder before making one',
      );
      expect(
        lookAt,
        lessThan(createAt),
        reason: 'looking after creating is what produced a second folder and '
            'hid the backups the user already had',
      );
      expect(
        body,
        contains('directory = true'),
        reason: 'the lookup must not adopt a file that shares the folder name',
      );
      expect(
        source,
        contains('DocumentsContract.Document.MIME_TYPE_DIR'),
        reason: 'the directory check is what makes the lookup a folder lookup',
      );
    });
  });

  group('in-app updates', () {
    final File channel = File(
      'android/app/src/main/kotlin/com/dhimmah/dhimmah/AppUpdateChannel.kt',
    );

    test('the channel names agree on both sides of the bridge', () {
      // A typo in either name is invisible until a device reports
      // MissingPluginException, which reads like a build problem rather than a
      // mismatch. The Dart constants are the ones the Kotlin file must carry.
      expect(channel.existsSync(), isTrue);
      final String source = channel.readAsStringSync();
      expect(source, contains('"${PlayAppUpdateService.methodChannelName}"'));
      expect(source, contains('"${PlayAppUpdateService.eventChannelName}"'));
    });

    test('it uses the per-feature Play library, not the retired bundle', () {
      final String gradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        gradle,
        contains('com.google.android.play:app-update'),
        reason: 'the update flow has to go through Google Play\'s own library',
      );
      expect(
        gradle,
        isNot(contains('com.google.android.play:core:')),
        reason: 'the old monolithic Play Core was split up and is superseded',
      );
    });

    test('the activity wires both channels and the result launcher', () {
      final String source = activity.readAsStringSync();
      for (final String needed in <String>[
        'AppUpdateChannel.METHOD_CHANNEL',
        'AppUpdateChannel.EVENT_CHANNEL',
        'registerForActivityResult',
        'configureFlutterEngine',
      ]) {
        expect(source, contains(needed), reason: '$needed is missing');
      }
      // The launcher has to be registered before the activity starts, so a
      // registration inside the first update check would crash on it.
      expect(
        source,
        contains('StartIntentSenderForResult'),
        reason: 'Play reports the update flow back through an IntentSender',
      );
    });

    test('the update path cannot reach the ledger', () {
      // The strongest thing that can be said about a feature that must not touch
      // user data is that it has no way to. An update replaces the app; it must
      // never migrate, clear, rebuild or read a database, and a prompt must
      // never know what is in one. This asserts the structure rather than
      // trusting the intent: none of the four files on the update path can name
      // the database, a repository or the ledger service.
      for (final String file in <String>[
        'lib/domain/services/app_update_service.dart',
        'lib/data/services/play_app_update_service.dart',
        'lib/app/app_update_controller.dart',
        'lib/core/widgets/app_update_card.dart',
      ]) {
        final String source = File(file).readAsStringSync();
        for (final String forbidden in <String>[
          'app_database',
          'ledger_service',
          'ledger_queries',
          'repositories/',
        ]) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason: '$file reaches $forbidden, which the update system must '
                'have no way to touch',
          );
        }
      }
    });

    test('nothing asks a server for a version', () {
      // The whole point of using Play's own system: the app makes no network
      // call of its own to find out about an update, and sends nothing.
      final String dart = File(
        'lib/data/services/play_app_update_service.dart',
      ).readAsStringSync();
      for (final String forbidden in <String>[
        'http://',
        'https://',
        'HttpClient',
        'package:http',
        'dio',
      ]) {
        expect(
          dart,
          isNot(contains(forbidden)),
          reason: 'the update check must not reach the network itself',
        );
      }
    });
  });

  group('refusal classification', () {
    // The distinction that matters: a user who dismissed the prompt must not be
    // told the feature is broken, and a platform that refused must not be
    // reported as a user cancel — which is exactly how the shipped bug hid.
    test('a refusal that no prompt could fix is reported as unavailable', () {
      for (final LocalAuthExceptionCode code in <LocalAuthExceptionCode>[
        // What a FlutterActivity produces.
        LocalAuthExceptionCode.uiUnavailable,
        LocalAuthExceptionCode.noCredentialsSet,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.noBiometricHardware,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
        LocalAuthExceptionCode.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout,
        LocalAuthExceptionCode.deviceError,
        LocalAuthExceptionCode.unknownError,
      ]) {
        expect(
          BiometricService.outcomeFor(code),
          BiometricOutcome.unavailable,
          reason: '${code.name} leaves the user with a dead button, so it has '
              'to be said out loud',
        );
      }
    });

    test('the user changing their mind is not an error', () {
      for (final LocalAuthExceptionCode code in <LocalAuthExceptionCode>[
        LocalAuthExceptionCode.userCanceled,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.authInProgress,
        LocalAuthExceptionCode.userRequestedFallback,
      ]) {
        expect(
          BiometricService.outcomeFor(code),
          BiometricOutcome.cancelled,
          reason: '${code.name} is not a failure the user needs told about',
        );
      }
    });
  });

  group('saving a backup to a file', () {
    final File channel = File(
      'android/app/src/main/kotlin/com/dhimmah/dhimmah/BackupFileChannel.kt',
    );

    test('both sides agree on the channel and on the document type', () {
      expect(channel.existsSync(), isTrue);
      final String source = channel.readAsStringSync();
      expect(source, contains('"${DocumentSaveChannel.methodChannelName}"'));
      // The type is part of the contract: the Kotlin side registers the create
      // contract with it, and a value that drifted apart would produce documents
      // providers refuse — the same failure that made the picker look empty.
      expect(source, contains('MIME_TYPE = "${DocumentSaveChannel.mimeType}"'));
      expect(
        DocumentSaveChannel.mimeType,
        isNot(contains('dhimmah')),
        reason: 'no provider knows a type for this format, so inventing one '
            'makes the document unopenable',
      );
    });

    test('it creates a document, rather than sending one to another app', () {
      final String source = channel.readAsStringSync();
      expect(
        activity.readAsStringSync(),
        contains('ActivityResultContracts.CreateDocument'),
        reason: 'ACTION_CREATE_DOCUMENT is the mechanism for "let the user '
            'choose where this new file goes"',
      );
      expect(
        source,
        contains('openOutputStream'),
        reason: 'the bytes are written through the ContentResolver, because a '
            'content:// URI is not a path Dart can open',
      );
      expect(
        source,
        contains('openInputStream'),
        reason: 'and read back the same way, so a copy is verified rather than '
            'assumed',
      );
      expect(
        source,
        contains('OpenableColumns'),
        reason: 'the provider is the authority on the name and size',
      );
      // A write that is not flushed and closed, or that happens on the frame
      // thread, is the kind of bug that shows up as a truncated backup.
      expect(source, contains('flush()'));
      expect(source, contains('use {'));
      expect(
        source,
        contains('Executors.newSingleThreadExecutor'),
        reason: 'megabytes of I/O do not belong on the thread drawing frames',
      );
    });

    test('the activity registers it and lets it go again', () {
      final String source = activity.readAsStringSync();
      expect(source, contains('BackupFileChannel.METHOD_CHANNEL'));
      // Both contracts are registered: the one that creates a single document,
      // and the one that grants standing access to a folder.
      expect(source, contains('ActivityResultContracts.CreateDocument'));
      expect(source, contains('ActivityResultContracts.OpenDocumentTree'));
      expect(
        source,
        contains('backupFileChannel?.dispose()'),
        reason: 'the channel holds a pending result and a thread; both are '
            'released with the activity',
      );
    });

    test('sharing is not the backup path', () {
      // The share sheet cannot report where a copy went, and on the phone this
      // was tested on it had no file destination at all. The gateway may offer a
      // share as a convenience; it must not be what the backup action calls.
      final String source =
          File('lib/core/files/file_gateway.dart').readAsStringSync();
      final String screen =
          File('lib/features/settings/backup_screen.dart').readAsStringSync();
      expect(
        screen,
        contains('saveExternal('),
        reason: 'the backup action saves a file',
      );
      expect(
        source,
        contains('createSaveTarget'),
        reason: 'the gateway has a real save destination',
      );
    });
  });
}
