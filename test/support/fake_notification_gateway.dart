import 'package:dhimmah/core/notifications/notification_gateway.dart';

/// One notification the fake platform is holding.
class FakeScheduledNotification {
  FakeScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
    required this.tier,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
  final NotificationTier tier;

  @override
  String toString() => 'FakeScheduledNotification($id, $payload, $when)';
}

/// An operating system that answers instantly and remembers everything.
///
/// The delivery policy — what to arm, what to cancel, what to leave alone — is
/// the part of the notification system that decides whether a user can trust a
/// reminder, and it must be testable without a phone, a plugin or a clock. This
/// is the other side of [NotificationGateway] for exactly that.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({
    this.supported = true,
    this.enabled = true,
    this.timezone = 'Asia/Riyadh',
    this.launch,
    this.scheduleFailure,
  });

  @override
  bool supported;

  /// What the platform answers for "may this app post notifications".
  bool enabled;

  /// The zone the device claims to be in.
  String? timezone;

  /// What `getNotificationAppLaunchDetails` answers, for a cold start.
  String? launch;

  /// When set, [schedule] throws it — a platform that refuses one alarm.
  Object? scheduleFailure;

  /// What the platform is holding, by id. This is the plugin's own persisted
  /// store on a real device, which is why reconciliation can compare against it.
  final Map<int, FakeScheduledNotification> held =
      <int, FakeScheduledNotification>{};

  /// Ids that were cancelled, in order.
  final List<int> cancelled = <int>[];

  /// Payloads shown immediately.
  final List<String> shown = <String>[];

  /// How many times the whole pending set was cancelled. The old service did
  /// this on every save, which also wiped the notification shade.
  int cancelAllPendingCalls = 0;

  int channelCreates = 0;
  int initializeCalls = 0;
  int permissionRequests = 0;

  /// How many times the pending set was read — once per reconciliation pass,
  /// which is how a test counts passes.
  int pendingReads = 0;

  /// The channel names last given, by tier.
  Map<NotificationTier, NotificationChannelCopy> channels =
      <NotificationTier, NotificationChannelCopy>{};

  void Function(String payload)? _onTap;

  /// A tap arriving while the app is running.
  void tap(String payload) => _onTap?.call(payload);

  /// The payloads currently armed, in no particular order.
  Set<String> get armedPayloads =>
      <String>{for (final FakeScheduledNotification n in held.values) n.payload};

  List<FakeScheduledNotification> get armed {
    final List<FakeScheduledNotification> out = held.values.toList()
      ..sort((FakeScheduledNotification a, FakeScheduledNotification b) =>
          a.when.compareTo(b.when));
    return out;
  }

  /// What the operating system would drop on its own, for a reboot test.
  void loseEverythingOnReboot() => held.clear();

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {
    initializeCalls++;
    _onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> createChannels(
    Map<NotificationTier, NotificationChannelCopy> copy,
  ) async {
    channelCreates++;
    channels = Map<NotificationTier, NotificationChannelCopy>.of(copy);
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  /// When false, the fake reports pending notifications without their words,
  /// as a platform that does not expose them would.
  bool reportsWording = true;

  /// When set, the next read of the pending set throws it — once. A platform
  /// that fails a whole reconciliation pass rather than a single alarm.
  Object? pendingFailure;

  @override
  Future<List<PendingNotification>> pending() async {
    pendingReads++;
    final Object? failure = pendingFailure;
    if (failure != null) {
      pendingFailure = null;
      throw failure;
    }
    return <PendingNotification>[
      for (final FakeScheduledNotification n in held.values)
        PendingNotification(
          id: n.id,
          payload: n.payload,
          title: reportsWording ? n.title : null,
          body: reportsWording ? n.body : null,
        ),
    ];
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
    if (scheduleFailure != null) throw scheduleFailure!;
    // Android replaces a notification that shares an id, which is the property
    // the whole id design leans on.
    held[id] = FakeScheduledNotification(
      id: id,
      title: title,
      body: body,
      when: when,
      payload: payload,
      tier: tier,
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
    shown.add(payload);
    held.remove(id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    held.remove(id);
  }

  @override
  Future<void> cancelAllPending() async {
    cancelAllPendingCalls++;
    held.clear();
  }

  @override
  Future<String?> localTimezone() async => timezone;
}
