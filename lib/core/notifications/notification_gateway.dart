import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// How loud a notification is allowed to be.
///
/// The tier decides the channel, and the channel decides what the user's phone
/// does with it. Three tiers, so the loud one keeps meaning something.
enum NotificationTier {
  /// Due today or already late.
  now,

  /// Due in the next few days.
  soon,

  /// A summary; nothing to do.
  digest,

  /// Something is wrong with the app itself and the user has to act — a copy
  /// that cannot be written, a folder whose permission was taken back.
  ///
  /// Deliberately its own channel rather than a louder use of an existing one:
  /// Android fixes a channel's importance when it is created, so a backup
  /// problem delivered on the "due now" channel would either be too quiet for
  /// the reminder it shares, or would make every reminder as loud as this. It is
  /// never *scheduled* — only shown — because it is about a moment that has
  /// already happened.
  alert,
}

/// One notification the platform is holding for a future moment.
///
/// What the platform reports back: an id, the payload that identifies the
/// record, and the words it will show. There is no scheduled time here — the
/// identity already carries the moment it is for, which is what makes two
/// schedules the same schedule. The words are what can still differ: the same
/// reminder, re-planned after a change of language, is the same notification
/// with different text.
@immutable
class PendingNotification {
  const PendingNotification({
    required this.id,
    this.payload,
    this.title,
    this.body,
  });

  final int id;
  final String? payload;

  /// Null when the platform does not say.
  final String? title;
  final String? body;

  @override
  bool operator ==(Object other) =>
      other is PendingNotification &&
      other.id == id &&
      other.payload == payload &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, payload, title, body);

  @override
  String toString() => 'PendingNotification($id, $payload)';
}

/// The platform's side of notifications, behind one narrow interface.
///
/// Everything that decides *what* should be pending lives above this line, in
/// `NotificationService` and the planner; everything that talks to Android lives
/// below it. That split is what makes the delivery policy — reconciliation,
/// cancellation, the cap, the cold-start tap — testable in plain Dart, which is
/// the only way the regression matrix in `test/core/notifications/` can run
/// without a phone.
abstract interface class NotificationGateway {
  /// Whether this platform can schedule notifications at all.
  bool get supported;

  /// Prepares the plugin and hands every tap to [onTap].
  Future<void> initialize({required void Function(String payload) onTap});

  /// The payload of the notification that launched the app, if it was one.
  ///
  /// Separate from [initialize]'s callback because Android answers this once,
  /// for a process that was started *by* the tap: the callback only fires for a
  /// tap that arrives while the app is already running.
  Future<String?> launchPayload();

  /// Creates (or updates the name of) the channels the tiers deliver on.
  Future<void> createChannels(Map<NotificationTier, NotificationChannelCopy> copy);

  /// Whether the user currently allows this app to post notifications.
  Future<bool> notificationsEnabled();

  /// Asks the operating system. Returns whether it is allowed afterwards.
  Future<void> requestPermission();

  /// What the platform is currently holding.
  Future<List<PendingNotification>> pending();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required NotificationTier tier,
  });

  /// Shows a notification now, for a moment that has already passed.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
    required NotificationTier tier,
  });

  /// Cancels one scheduled notification. Never touches what is on screen.
  Future<void> cancel(int id);

  /// Cancels everything scheduled. Never touches what is on screen.
  Future<void> cancelAllPending();

  /// The device's current timezone name, for detecting a change.
  Future<String?> localTimezone();
}

/// The localised name and description of one channel.
@immutable
class NotificationChannelCopy {
  const NotificationChannelCopy({required this.name, required this.body});

  final String name;
  final String body;
}

/// The real gateway: `flutter_local_notifications` plus the timezone database.
///
/// This is the only file in the app that imports the plugin.
class FlutterLocalNotificationsGateway implements NotificationGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The channel ids. Fixed constants, never derived from a record: a channel
  /// per debt would be hundreds of entries in the system settings, and Android
  /// never lets an app change a channel's importance after it is created.
  static const Map<NotificationTier, String> channelIds = <NotificationTier, String>{
    NotificationTier.now: 'dhimmah_due',
    NotificationTier.soon: 'dhimmah_upcoming',
    NotificationTier.digest: 'dhimmah_monthly_summary',
    NotificationTier.alert: 'dhimmah_backup',
  };

  Map<NotificationTier, NotificationChannelCopy> _copy =
      const <NotificationTier, NotificationChannelCopy>{};

  @override
  bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {
    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      // Falls back to UTC. The instant a reminder is for is unaffected — a local
      // wall-clock DateTime carries its own offset — but the zone name is what
      // the change detector compares, so it stays null rather than guessing.
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      // Permission is requested at the moment the user turns reminders on,
      // never as a surprise at first launch.
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    try {
      final NotificationAppLaunchDetails? details =
          await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final String? payload = details.notificationResponse?.payload;
      return (payload == null || payload.isEmpty) ? null : payload;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> createChannels(
    Map<NotificationTier, NotificationChannelCopy> copy,
  ) async {
    _copy = copy;
    if (!supported || !Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final MapEntry<NotificationTier, NotificationChannelCopy> entry
        in copy.entries) {
      // Android keeps a channel's importance and sound once it exists and only
      // lets the app update its name and description, which is exactly what
      // re-running this on every launch does after a language change.
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelIds[entry.key]!,
          entry.value.name,
          description: entry.value.body,
          importance: entry.key == NotificationTier.now
              ? Importance.high
              : Importance.defaultImportance,
        ),
      );
    }
  }

  @override
  Future<bool> notificationsEnabled() async {
    if (!supported) return false;
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios =
            _plugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final NotificationsEnabledOptions? options =
            await ios?.checkPermissions();
        return options?.isEnabled ?? false;
      }
    } on Object {
      return false;
    }
    return false;
  }

  @override
  Future<void> requestPermission() async {
    if (!supported) return;
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        // Not `requestExactAlarmsPermission()`: reminders here are deliberately
        // inexact (see [schedule]), so the permission would buy nothing, and
        // asking for a capability the app does not use is what erodes trust.
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios =
            _plugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } on Object {
      // A denied or unavailable prompt is not an error worth surfacing here.
    }
  }

  @override
  Future<List<PendingNotification>> pending() async {
    if (!supported) return const <PendingNotification>[];
    try {
      final List<PendingNotificationRequest> requests =
          await _plugin.pendingNotificationRequests();
      return <PendingNotification>[
        for (final PendingNotificationRequest request in requests)
          PendingNotification(
            id: request.id,
            payload: request.payload,
            title: request.title,
            body: request.body,
          ),
      ];
    } on Object {
      return const <PendingNotification>[];
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required NotificationTier tier,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(tier),
      // Inexact on purpose. A debt reminder is "look at this today", not an
      // alarm clock: a few minutes of slack costs the user nothing, and exact
      // scheduling needs a permission that Android 14+ no longer grants by
      // default and that Play restricts to alarm and calendar apps.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
    required NotificationTier tier,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(tier),
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: id);
    } on Object {
      // Ignored: a failed cancel is retried by the next reconciliation.
    }
  }

  @override
  Future<void> cancelAllPending() async {
    if (!supported) return;
    try {
      // `cancelAll` would also clear the notifications already on screen, which
      // is the user's history, not ours to wipe. This cancels only the future.
      await _plugin.cancelAllPendingNotifications();
    } on Object {
      // Ignored.
    }
  }

  @override
  Future<String?> localTimezone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } on Object {
      return null;
    }
  }

  NotificationDetails _details(NotificationTier tier) {
    // The name and description here are only used if the channel does not exist
    // yet — the copy created in [createChannels] is what the user reads — so
    // they are taken from the same localised map rather than hardcoded.
    final NotificationChannelCopy copy = _copy[tier] ??
        const NotificationChannelCopy(name: 'Dhimmah', body: '');
    final AndroidNotificationDetails android = switch (tier) {
      NotificationTier.now => AndroidNotificationDetails(
          channelIds[NotificationTier.now]!,
          copy.name,
          channelDescription: copy.body,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          groupKey: 'dhimmah_due',
          // Private: a locked screen shows the app, not the amount, unless the
          // user asks otherwise in the system settings.
          visibility: NotificationVisibility.private,
        ),
      NotificationTier.soon => AndroidNotificationDetails(
          channelIds[NotificationTier.soon]!,
          copy.name,
          channelDescription: copy.body,
          category: AndroidNotificationCategory.reminder,
          groupKey: 'dhimmah_upcoming',
          visibility: NotificationVisibility.private,
        ),
      NotificationTier.digest => AndroidNotificationDetails(
          channelIds[NotificationTier.digest]!,
          copy.name,
          channelDescription: copy.body,
          category: AndroidNotificationCategory.status,
          groupKey: 'dhimmah_summary',
          visibility: NotificationVisibility.private,
        ),
      // A problem with the app itself. High importance, like a payment that is
      // already late and for the same reason: it is about something that has
      // already gone wrong, not about something coming up. Its own channel, so a
      // user who finds it noisy can quieten it without also quietening their
      // reminders.
      NotificationTier.alert => AndroidNotificationDetails(
          channelIds[NotificationTier.alert]!,
          copy.name,
          channelDescription: copy.body,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.error,
          groupKey: 'dhimmah_backup',
          visibility: NotificationVisibility.private,
        ),
    };
    const DarwinNotificationDetails darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }
}
