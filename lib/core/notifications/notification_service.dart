import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import 'notification_composer.dart';
import 'notification_gateway.dart';

/// Whether the app may post notifications.
enum NotificationPermission {
  granted,
  denied,
  unsupported;

  bool get isGrantedOrUnsupported =>
      this == NotificationPermission.granted ||
      this == NotificationPermission.unsupported;
}

/// What one reconciliation did, for the diagnostics screen and the tests.
@immutable
class NotificationSyncResult {
  const NotificationSyncResult({
    required this.desired,
    required this.armed,
    required this.scheduled,
    required this.cancelled,
    required this.droppedByCap,
    required this.blocked,
    this.reworded = 0,
    this.recordsRead = 0,
    this.armedIds = const <int>{},
  });

  const NotificationSyncResult.blocked()
      : desired = 0,
        armed = 0,
        scheduled = 0,
        cancelled = 0,
        reworded = 0,
        droppedByCap = 0,
        blocked = true,
        recordsRead = 0,
        armedIds = const <int>{};

  /// The ids the platform is holding after this pass, of those that were
  /// wanted: already there, or scheduled now.
  ///
  /// What a caller needs to know that one particular notification will arrive —
  /// the month-end summary records its month as handed over only when it is in
  /// here, so a summary the cap left out or the platform refused is still
  /// delivered by the catch-up.
  final Set<int> armedIds;

  /// How many notifications the records ask for.
  final int desired;

  /// How many of them the platform is now holding.
  final int armed;

  /// Newly scheduled in this pass.
  final int scheduled;

  /// Removed because they are no longer wanted.
  final int cancelled;

  /// Already armed, but re-scheduled because their words changed — a new
  /// language, a new numeral style, a renamed person — so the reminder that
  /// arrives says what the app says today.
  final int reworded;

  /// Wanted, but beyond [NotificationService.maxScheduled] and left for a later
  /// reconciliation.
  final int droppedByCap;

  /// True when the user has not allowed notifications, so nothing was armed.
  final bool blocked;

  /// How many records the plan had to read to produce [desired].
  ///
  /// The number that says whether a save is proportional to what asks for a
  /// reminder or to the size of the ledger.
  final int recordsRead;

  bool get changed => scheduled > 0 || cancelled > 0 || reworded > 0;
}

/// Decides what the operating system should be holding, and keeps it in step
/// with the ledger.
///
/// The rule that shapes everything here: **the database is the source of truth
/// and a pending notification is only a scheduled representation of it.** So the
/// service never patches one notification — it works out the complete set the
/// records currently ask for and makes the platform agree with it, cancelling
/// what is no longer wanted and scheduling what is missing.
///
/// Two consequences worth stating, because both were wrong before:
///
/// * Reconciliation cancels *pending* notifications only. The old
///   `cancelAll()` also cleared the notification shade, so every save wiped the
///   reminders the user had already received.
/// * Only the soonest [maxScheduled] are armed. Android — and Samsung's
///   implementation in particular — does not hold an unbounded number of alarms
///   per app, and a ledger with thousands of records asks for more than any
///   phone will keep. The soonest are always among them, and every launch, every
///   save and every environment change re-runs this.
class NotificationService {
  NotificationService({NotificationGateway? gateway})
      : _gateway = gateway ?? FlutterLocalNotificationsGateway();

  final NotificationGateway _gateway;

  /// The most notifications the app will ask a phone to hold at once.
  ///
  /// Samsung's Android build documents a ceiling of 500 alarms per app through
  /// `AlarmManager`, and exceeding it throws rather than degrading; 400 leaves
  /// room for the channel and summary entries without ever testing that edge.
  /// The selection is by time, so the records that need reminding soonest are
  /// the ones that are armed.
  static const int maxScheduled = 400;

  bool _initialized = false;
  NotificationPermission _permission = NotificationPermission.unsupported;

  /// The timezone the schedules were computed in, so a change can be noticed.
  String? _timezone;

  /// Payloads from notifications the user tapped, for deep linking.
  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Every permission value this service has held, newest last.
  ///
  /// A stream rather than a plain getter because the user can grant or revoke
  /// notifications in the system settings while Dhimmah is in the background:
  /// a screen that read the value once would go on describing a phone that no
  /// longer exists.
  final StreamController<NotificationPermission> _permissions =
      StreamController<NotificationPermission>.broadcast();

  /// The tap that launched the app, if it was launched by one.
  ///
  /// Held rather than pushed into [taps]: on a cold start there is no listener
  /// yet, and a broadcast stream drops what nobody is listening for — which is
  /// how a tap on a reminder used to open the dashboard instead of the record.
  String? _launchPayload;

  Stream<String> get taps => _taps.stream;

  /// The payload the app was launched by, consumed once.
  String? takeLaunchPayload() {
    final String? payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  NotificationPermission get permission => _permission;

  /// The phone's time zone as an IANA name (`Asia/Aden`), as last read: at
  /// start-up and on every return to the foreground. Null before start-up,
  /// where reminders are not supported, or when the phone does not say.
  ///
  /// Read here because this service is where the time-zone plugin is used; the
  /// suggested currency is the other reader.
  String? get timeZone => _timezone;

  /// The permission, then every change to it.
  Stream<NotificationPermission> get permissionChanges async* {
    yield _permission;
    yield* _permissions.stream;
  }

  void _setPermission(NotificationPermission permission) {
    _permission = permission;
    if (!_permissions.isClosed) _permissions.add(permission);
  }

  /// True when this platform can schedule notifications at all.
  bool get supportsScheduling => _gateway.supported;

  /// Prepares the plugin, the timezone database and the notification channels.
  Future<void> initialize({required AppLocalizations localizations}) async {
    if (_initialized) return;
    if (!supportsScheduling) {
      _initialized = true;
      _setPermission(NotificationPermission.unsupported);
      return;
    }

    await _gateway.initialize(onTap: _emit);
    await _gateway.createChannels(_channelCopy(localizations));
    _timezone = await _gateway.localTimezone();
    _launchPayload = await _gateway.launchPayload();

    _initialized = true;
    _setPermission(await _readPermission());
    _log('initialised: permission=${_permission.name} timezone=$_timezone');
  }

  /// Renames the notification channels into [localizations]' language.
  ///
  /// The channels are named once, at start-up, and Android shows those names in
  /// the system's notification settings — so after a change of language they
  /// went on reading in the old one until the next launch. Android lets an app
  /// rename a channel it already created; importance and sound are fixed at
  /// creation and stay exactly as the user left them.
  Future<void> relabelChannels(AppLocalizations localizations) async {
    if (!_initialized || !supportsScheduling) return;
    await _gateway.createChannels(_channelCopy(localizations));
  }

  /// Re-reads the environment after the app comes back to the foreground.
  ///
  /// The user can grant or revoke notifications in the system settings while
  /// Dhimmah is in the background, and the device can change timezone in a
  /// pocket. Either one changes what should be armed, and neither is visible to
  /// a process that only reads them once at start-up.
  Future<NotificationEnvironment> refreshEnvironment() async {
    if (!_initialized || !supportsScheduling) {
      return const NotificationEnvironment(changed: false);
    }
    final NotificationPermission before = _permission;
    _setPermission(await _readPermission());

    final String? zone = await _gateway.localTimezone();
    final bool zoneChanged = zone != null && zone != _timezone;
    if (zoneChanged) {
      // Re-reading the location is what makes "20:00 local time" mean the local
      // time of wherever the phone is now, rather than where it was when the
      // schedules were computed.
      await _gateway.initialize(onTap: _emit);
      _timezone = zone;
    }

    final bool permissionChanged = before != _permission;
    final bool nowAllowed = before != NotificationPermission.granted &&
        _permission == NotificationPermission.granted;
    if (permissionChanged || zoneChanged) {
      _log('environment changed: permission=${_permission.name} '
          'timezoneChanged=$zoneChanged');
    }
    return NotificationEnvironment(
      changed: permissionChanged || zoneChanged,
      permission: _permission,
      // A revoked permission leaves nothing to do; a granted one has to arm
      // everything the ledger asks for.
      mustReschedule: nowAllowed || zoneChanged,
    );
  }

  /// Asks the operating system for permission. Safe to call more than once.
  Future<NotificationPermission> requestPermission() async {
    if (!supportsScheduling) return NotificationPermission.unsupported;
    await _gateway.requestPermission();
    _setPermission(await _readPermission());
    _log('permission after request: ${_permission.name}');
    return _permission;
  }

  /// Makes the platform hold exactly the notifications in [desired].
  ///
  /// Idempotent by construction: running it with the same records twice asks the
  /// platform for the same ids, finds them already pending, and does nothing the
  /// second time. Running it after an edit cancels the id that no longer exists
  /// and schedules the one that does, so a changed reminder can never end up as
  /// two notifications.
  Future<NotificationSyncResult> sync(
    List<ComposedNotification> desired, {
    int recordsRead = 0,
  }) async {
    if (!supportsScheduling) {
      return const NotificationSyncResult.blocked();
    }
    if (_permission == NotificationPermission.denied) {
      // Nothing can be delivered, so nothing should be held: the user has said
      // no, and a pending set that cannot fire would only mislead the UI.
      await _gateway.cancelAllPending();
      _log('sync skipped: notifications are denied');
      return const NotificationSyncResult.blocked();
    }

    final List<ComposedNotification> armed = selectArmed(desired);

    final Set<int> wanted = <int>{
      for (final ComposedNotification n in armed) n.id,
    };
    final List<PendingNotification> pending = await _gateway.pending();
    final Map<int, PendingNotification> held = <int, PendingNotification>{
      for (final PendingNotification n in pending) n.id: n,
    };

    int cancelled = 0;
    for (final PendingNotification notification in pending) {
      if (wanted.contains(notification.id)) continue;
      await _gateway.cancel(notification.id);
      cancelled++;
    }

    int scheduled = 0;
    int reworded = 0;
    final Set<int> armedIds = <int>{};
    for (final ComposedNotification notification in armed) {
      final PendingNotification? existing = held[notification.id];
      if (existing != null && !_wordingChanged(existing, notification)) {
        armedIds.add(notification.id);
        continue;
      }
      // A reminder the platform already holds is still armed if its re-wording
      // fails: it arrives, in its old words.
      if (existing != null) armedIds.add(notification.id);
      try {
        // An existing id is replaced in place, which is Android's own rule and
        // the one the whole id scheme leans on: the reminder keeps its identity
        // and its moment, and only its words change.
        await _gateway.schedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          when: notification.when,
          payload: notification.payload,
          tier: _tierFor(notification.priority),
        );
        armedIds.add(notification.id);
        if (existing == null) {
          scheduled++;
        } else {
          reworded++;
        }
      } on Object catch (error, stack) {
        // One un-schedulable notification must not take the app down or stop the
        // rest: the ledger is already saved, and the next reconciliation tries
        // again.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'dhimmah notifications',
            context: ErrorDescription(
              'scheduling notification ${notification.id}',
            ),
          ),
        );
      }
    }

    final NotificationSyncResult result = NotificationSyncResult(
      desired: desired.length,
      armed: armed.length,
      scheduled: scheduled,
      cancelled: cancelled,
      reworded: reworded,
      droppedByCap: desired.length - armed.length,
      blocked: false,
      recordsRead: recordsRead,
      armedIds: armedIds,
    );
    if (result.changed || result.droppedByCap > 0) {
      _log('sync: desired=${result.desired} armed=${result.armed} '
          'scheduled=${result.scheduled} cancelled=${result.cancelled} '
          'reworded=${result.reworded} overCap=${result.droppedByCap}');
    }
    return result;
  }

  /// Whether what the platform holds would say something other than [wanted].
  ///
  /// Identity alone used to decide, and identity is the record, the kind and
  /// the moment — not the words. So a reminder planned in Arabic stayed Arabic
  /// after the user switched to English, and one that named an amount kept the
  /// old amount after a correction, until its moment passed. A platform that
  /// does not report the words is trusted rather than rewritten every pass.
  static bool _wordingChanged(
    PendingNotification held,
    ComposedNotification wanted,
  ) =>
      (held.title != null && held.title != wanted.title) ||
      (held.body != null && held.body != wanted.body);

  /// The notifications a phone is asked to hold: the soonest, and no more than
  /// [maxScheduled].
  ///
  /// Ties are broken by id, so the choice is a function of the records alone.
  /// Without that, a cap cutting through a group of notifications that share a
  /// moment could pick different members on different passes — and Android would
  /// answer each swap by cancelling one notification and scheduling another, for
  /// nothing.
  static List<ComposedNotification> selectArmed(
    List<ComposedNotification> desired, {
    int limit = maxScheduled,
  }) {
    final List<ComposedNotification> ordered =
        List<ComposedNotification>.of(desired)
          ..sort((ComposedNotification a, ComposedNotification b) {
            final int byTime = a.when.compareTo(b.when);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    return ordered.length > limit ? ordered.sublist(0, limit) : ordered;
  }

  /// Shows a notification immediately, for a moment that has already passed.
  Future<void> showNow(ComposedNotification notification) async {
    if (!supportsScheduling) return;
    try {
      await _gateway.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        tier: _tierFor(notification.priority),
      );
    } on Object {
      // Nothing actionable: the in-app report still shows the same numbers.
    }
  }

  Future<void> cancelAll() async {
    if (!supportsScheduling) return;
    await _gateway.cancelAllPending();
  }

  Future<void> cancel(int id) async {
    if (!supportsScheduling) return;
    await _gateway.cancel(id);
  }

  /// How many notifications the platform is holding. Used by diagnostics.
  Future<int> pendingCount() async {
    if (!supportsScheduling) return 0;
    return (await _gateway.pending()).length;
  }

  void dispose() {
    _taps.close();
    _permissions.close();
  }

  Future<NotificationPermission> _readPermission() async {
    if (!supportsScheduling) return NotificationPermission.unsupported;
    return await _gateway.notificationsEnabled()
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  void _emit(String payload) {
    _log('tapped: ${_kindOf(payload)}');
    if (_taps.isClosed) return;
    _taps.add(payload);
  }

  Map<NotificationTier, NotificationChannelCopy> _channelCopy(
    AppLocalizations localizations,
  ) =>
      <NotificationTier, NotificationChannelCopy>{
        NotificationTier.now: NotificationChannelCopy(
          name: localizations.notifChannelDueName,
          body: localizations.notifChannelDueBody,
        ),
        NotificationTier.soon: NotificationChannelCopy(
          name: localizations.notifChannelUpcomingName,
          body: localizations.notifChannelUpcomingBody,
        ),
        NotificationTier.digest: NotificationChannelCopy(
          name: localizations.notifChannelSummaryName,
          body: localizations.notifChannelSummaryBody,
        ),
        NotificationTier.alert: NotificationChannelCopy(
          name: localizations.notifChannelBackupName,
          body: localizations.notifChannelBackupBody,
        ),
      };

  static NotificationTier _tierFor(NotificationPriority priority) =>
      switch (priority) {
        NotificationPriority.now => NotificationTier.now,
        NotificationPriority.soon => NotificationTier.soon,
        NotificationPriority.digest => NotificationTier.digest,
        NotificationPriority.alert => NotificationTier.alert,
      };

  /// The record kind from a payload, for a log line that carries no data.
  static String _kindOf(String payload) {
    final int separator = payload.indexOf(':');
    return separator <= 0 ? 'unknown' : payload.substring(0, separator);
  }

  /// Diagnostics for a debug build: counts and kinds, never an amount or a name.
  static void _log(String message) {
    if (kDebugMode) debugPrint('Dhimmah notifications: $message');
  }
}

/// What [NotificationService.refreshEnvironment] found.
@immutable
class NotificationEnvironment {
  const NotificationEnvironment({
    required this.changed,
    this.permission = NotificationPermission.unsupported,
    this.mustReschedule = false,
  });

  /// True when the permission or the timezone is not what it was.
  final bool changed;

  final NotificationPermission permission;

  /// True when the caller has to rebuild the pending set.
  final bool mustReschedule;
}
