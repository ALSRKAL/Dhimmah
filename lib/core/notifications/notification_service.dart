import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/generated/app_localizations.dart';
import 'notification_composer.dart';

/// Whether the app may post notifications.
enum NotificationPermission { granted, denied, unsupported }

/// Wraps `flutter_local_notifications` behind the small surface Dhimmah needs.
///
/// Two deliberate choices:
///
/// * Scheduling is only attempted on Android and iOS. Desktop targets are used
///   for development, and pretending to schedule there would make the planner
///   look like it works when nothing was delivered.
/// * Delivery is "replace the whole set", never "add one". Paying a debt off
///   therefore cancels its pending reminders automatically, which is the only way
///   to guarantee a settled record can never nag the user.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  NotificationPermission _permission = NotificationPermission.unsupported;

  /// Payloads from notifications the user tapped, for deep linking.
  final StreamController<String> _taps = StreamController<String>.broadcast();

  Stream<String> get taps => _taps.stream;

  NotificationPermission get permission => _permission;

  /// True when this platform can schedule notifications at all.
  static bool get supportsScheduling =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Due today, or already late. These are the ones worth interrupting for.
  static const String channelDue = 'dhimmah_due';

  /// A few days out. Worth a glance, not an interruption.
  static const String channelUpcoming = 'dhimmah_upcoming';

  static const String channelSummary = 'dhimmah_monthly_summary';

  /// Prepares the plugin, the timezone database and the notification channels.
  Future<void> initialize({required AppLocalizations localizations}) async {
    if (_initialized) return;
    if (kIsWeb) return;

    // The timezone database is what makes "8:00 PM local time" mean the same
    // thing after the device crosses a timezone.
    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      // Falls back to UTC; scheduling still works, just anchored to UTC.
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      // Permission is requested explicitly at the moment the user turns
      // reminders on, never as a surprise at first launch.
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
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelDue,
          localizations.notifChannelDueName,
          description: localizations.notifChannelDueBody,
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelUpcoming,
          localizations.notifChannelUpcomingName,
          description: localizations.notifChannelUpcomingBody,
        ),
      );
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelSummary,
          localizations.notifChannelSummaryName,
          description: localizations.notifChannelSummaryBody,
        ),
      );
    }

    _initialized = true;
    _permission = await _readPermission();
  }

  Future<NotificationPermission> _readPermission() async {
    if (!supportsScheduling) return NotificationPermission.unsupported;
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? enabled = await android?.areNotificationsEnabled();
        return enabled == true
            ? NotificationPermission.granted
            : NotificationPermission.denied;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios =
            _plugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final NotificationsEnabledOptions? options =
            await ios?.checkPermissions();
        return options?.isEnabled == true
            ? NotificationPermission.granted
            : NotificationPermission.denied;
      }
    } on Object {
      return NotificationPermission.denied;
    }
    return NotificationPermission.unsupported;
  }

  /// Asks the operating system for permission. Safe to call more than once.
  Future<NotificationPermission> requestPermission() async {
    if (!supportsScheduling) return NotificationPermission.unsupported;
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        // Not `requestExactAlarmsPermission()`: that call takes the user out of
        // the app and into a system settings screen, and scheduling here is
        // deliberately inexact (`AndroidScheduleMode.inexactAllowWhileIdle`), so
        // the permission would buy nothing. Asking for a capability the app does
        // not use is the kind of permission request that erodes trust.
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios =
            _plugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } on Object {
      // A denied or unavailable prompt is not an error worth surfacing here.
    }
    _permission = await _readPermission();
    return _permission;
  }

  /// Replaces every pending notification with [notifications].
  ///
  /// Cancelling first is what keeps the delivered set exactly in step with the
  /// records: there is no code path that adds a notification without rebuilding
  /// the whole set first.
  Future<void> sync(List<ComposedNotification> notifications) async {
    if (!supportsScheduling) return;
    await cancelAll();
    if (_permission == NotificationPermission.denied) return;

    for (final ComposedNotification notification in notifications) {
      await _schedule(notification);
    }
  }

  Future<void> _schedule(ComposedNotification notification) async {
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(notification.when, tz.local),
        notificationDetails: _details(notification),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notification.payload,
      );
    } on Object catch (error, stack) {
      // A single un-schedulable notification must never take the app down; the
      // remaining ones still matter.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'dhimmah notifications',
          context: ErrorDescription('scheduling notification ${notification.id}'),
        ),
      );
    }
  }

  /// Shows a notification immediately. Used for the month-end catch-up, where
  /// the moment has already passed while the app was closed.
  Future<void> showNow(ComposedNotification notification) async {
    if (!supportsScheduling) return;
    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: _details(notification),
        payload: notification.payload,
      );
    } on Object {
      // Nothing actionable: the in-app report still shows the same numbers.
    }
  }

  NotificationDetails _details(ComposedNotification notification) {
    // Three tiers, so the loud one still means something.
    final AndroidNotificationDetails android = switch (notification.priority) {
      NotificationPriority.now => AndroidNotificationDetails(
          channelDue,
          'Due now',
          channelDescription: 'A payment is due today or already late',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          groupKey: 'dhimmah_due',
        ),
      NotificationPriority.soon => AndroidNotificationDetails(
          channelUpcoming,
          'Coming up',
          channelDescription: 'A payment falls due in the next few days',
          category: AndroidNotificationCategory.reminder,
          groupKey: 'dhimmah_upcoming',
        ),
      NotificationPriority.digest => AndroidNotificationDetails(
          channelSummary,
          'Monthly summary',
          channelDescription: 'A summary of your ledger at the end of each month',
          category: AndroidNotificationCategory.status,
          groupKey: 'dhimmah_summary',
        ),
    };
    const DarwinNotificationDetails darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  Future<void> cancelAll() async {
    if (!supportsScheduling) return;
    try {
      await _plugin.cancelAll();
    } on Object {
      // Ignored: a failed cancel is retried on the next sync.
    }
  }

  Future<void> cancel(int id) async {
    if (!supportsScheduling) return;
    try {
      await _plugin.cancel(id: id);
    } on Object {
      // Ignored.
    }
  }

  /// The notifications currently pending, used by the diagnostics in Settings.
  Future<int> pendingCount() async {
    if (!supportsScheduling) return 0;
    try {
      final List<PendingNotificationRequest> pending =
          await _plugin.pendingNotificationRequests();
      return pending.length;
    } on Object {
      return 0;
    }
  }

  void dispose() {
    _taps.close();
  }
}
