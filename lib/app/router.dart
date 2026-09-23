import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/more_screen.dart';

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
      'report' => reports,
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
          final String? direction = state.uri.queryParameters['direction'];
          return DebtFormScreen(
            direction: direction == null
                ? DebtDirection.iOwe
                : (direction == DebtDirection.owedToMe.name
                    ? DebtDirection.owedToMe
                    : DebtDirection.iOwe),
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
        builder: (BuildContext context, GoRouterState state) =>
            const ReportsScreen(),
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
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(state.error?.toString() ?? 'Not found')),
    ),
  );
}
