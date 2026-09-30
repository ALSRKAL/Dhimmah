import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/empty_state.dart';
import '../domain/enums/debt_enums.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/debts/debt_detail_screen.dart';
import '../features/debts/debt_form_screen.dart';
import '../features/debts/debt_ledger_screen.dart';
import '../features/debts/records_screen.dart';
import '../features/obligations/obligation_detail_screen.dart';
import '../features/obligations/obligation_form_screen.dart';
import '../features/obligations/obligations_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/person_detail_screen.dart';
import '../features/people/person_form_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/more_screen.dart';
import '../l10n/generated/app_localizations.dart';

/// Every route in Dhimmah, in one place.
///
/// The five destinations of the bottom bar live in one shell so their scroll
/// positions survive switching tabs; everything else is pushed on top, which
/// keeps the back gesture behaving the way a phone user expects.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String onboarding = '/onboarding';
  static const String dashboard = '/';
  /// The single ledger, filtered by side. The `direction` query parameter picks
  /// which side is shown, so the dashboard can still deep-link to either.
  static const String ledger = '/ledger';
  static const String people = '/people';
  static const String obligations = '/obligations';
  static const String more = '/more';

  static const String backup = '/backup';
  static const String personNew = '/people/new';
  static const String personDetail = '/people/:id';
  static const String personEdit = '/people/:id/edit';

  static const String debtNew = '/debts/new';
  static const String debtDetail = '/debts/:id';
  static const String debtEdit = '/debts/:id/edit';

  static const String obligationsNew = '/obligations/new';

  static const String reminders = '/reminders';
  static const String reminderNew = '/reminders/new';

  static const String records = '/records';
  static const String reports = '/reports';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String about = '/about';

  /// The ledger showing one side, used by the dashboard's two figures.
  static String ledgerPath(DebtDirection direction) =>
      '$ledger?side=${direction.name}';

  static String personPath(String id) => '/people/$id';
  static String personEditPath(String id) => '/people/$id/edit';
  static String debtPath(String id) => '/debts/$id';
  static String debtEditPath(String id) => '/debts/$id/edit';
  static String obligationPath(String id) => '/obligations/$id';
  static String obligationEditPath(String id) => '/obligations/$id/edit';
  static String reminderPath(String id) => '/reminders/$id/edit';

  /// The report for one month, by its `yyyy-MM` key.
  static String reportsPath(String monthKey) => '$reports?month=$monthKey';

  /// The month a `yyyy-MM` key names, or null when it names none.
  static DateTime? monthFromKey(String? key) {
    if (key == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(key)) return null;
    final int year = int.parse(key.substring(0, 4));
    final int month = int.parse(key.substring(5));
    if (month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  /// Route for the record a notification points at.
  static String? forNotificationPayload(String payload) {
    final int separator = payload.indexOf(':');
    if (separator <= 0) return null;
    final String kind = payload.substring(0, separator);
    final String id = payload.substring(separator + 1);
    return switch (kind) {
      'debt' => debtPath(id),
      'obligation' => obligationPath(id),
      'person' => personPath(id),
      'reminder' => reminderPath(id),
      // The month the summary is about. It used to open the current month, so
      // September's summary, tapped on 2 October, showed October's figures.
      'report' => monthFromKey(id) == null ? reports : reportsPath(id),
      // The backup alert opens the screen where the problem is fixed; it used
      // to match nothing, so tapping it did nothing at all.
      'backup' => backup,
      _ => null,
    };
  }
}

/// Builds the app's router.
///
/// [onboardingCompleted] decides the first location. It is read once at startup
/// rather than watched, because redirecting a user out of a screen they are
/// already using would be worse than opening the wrong tab on a cold start.
GoRouter buildRouter({
  required bool onboardingCompleted,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation:
        onboardingCompleted ? AppRoutes.dashboard : AppRoutes.onboarding,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) =>
            AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.ledger,
                builder: (BuildContext context, GoRouterState state) {
                  final String? side = state.uri.queryParameters['side'];
                  return DebtLedgerScreen(
                    initialDirection:
                        side == DebtDirection.owedToMe.name
                            ? DebtDirection.owedToMe
                            : DebtDirection.iOwe,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.people,
                builder: (BuildContext context, GoRouterState state) =>
                    const PeopleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.obligations,
                builder: (BuildContext context, GoRouterState state) =>
                    const ObligationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.more,
                builder: (BuildContext context, GoRouterState state) =>
                    const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.backup,
        builder: (BuildContext context, GoRouterState state) =>
            const BackupScreen(),
      ),
      GoRoute(
        path: AppRoutes.personNew,
        builder: (BuildContext context, GoRouterState state) =>
            const PersonFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.personDetail,
        builder: (BuildContext context, GoRouterState state) =>
            PersonDetailScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.personEdit,
        builder: (BuildContext context, GoRouterState state) =>
            PersonFormScreen(personId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.debtNew,
        builder: (BuildContext context, GoRouterState state) {
          // Only what the route actually said: no side is a question for the
          // form to ask, not a default for it to assume.
          return DebtFormScreen(
            direction: DebtDirection.fromName(
              state.uri.queryParameters['direction'],
            ),
            personId: state.uri.queryParameters['person'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.debtDetail,
        builder: (BuildContext context, GoRouterState state) =>
            DebtDetailScreen(debtId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.debtEdit,
        builder: (BuildContext context, GoRouterState state) =>
            DebtFormScreen(debtId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.obligationsNew,
        builder: (BuildContext context, GoRouterState state) =>
            const ObligationFormScreen(),
      ),
      GoRoute(
        path: '/obligations/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ObligationDetailScreen(obligationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/obligations/:id/edit',
        builder: (BuildContext context, GoRouterState state) =>
            ObligationFormScreen(obligationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        builder: (BuildContext context, GoRouterState state) =>
            const RemindersScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminderNew,
        builder: (BuildContext context, GoRouterState state) =>
            const ReminderFormScreen(),
      ),
      GoRoute(
        path: '/reminders/:id/edit',
        builder: (BuildContext context, GoRouterState state) =>
            ReminderFormScreen(reminderId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.records,
        builder: (BuildContext context, GoRouterState state) => RecordsScreen(
          filter: state.uri.queryParameters['filter'],
          directionName: state.uri.queryParameters['direction'],
        ),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (BuildContext context, GoRouterState state) => ReportsScreen(
          initialMonth:
              AppRoutes.monthFromKey(state.uri.queryParameters['month']),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
      ),
    ],
    // A location nothing matches — a stale link, a record that is gone. It used
    // to print the router's own exception text, in English, with no way out
    // but the back button.
    errorBuilder: (BuildContext context, GoRouterState state) {
      final AppLocalizations localizations = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline,
          title: localizations.recordGone,
          actionLabel: localizations.navHome,
          onAction: () => context.go(AppRoutes.dashboard),
        ),
      );
    },
  );
}
