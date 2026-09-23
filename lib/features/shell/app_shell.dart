import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import 'add_action_sheet.dart';

/// The five-destination shell.
///
/// An indexed stack keeps each tab's scroll position, so moving between "I owe"
/// and "owed to me" does not lose the user's place. The add button is an extended
/// FAB rather than a bare plus: adding a record is the app's most important
/// action, and a labelled button is unmistakable.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    // Branch 2 is the people directory.
    final bool onPeopleTab = shell.currentIndex == 2;

    return Scaffold(
      body: shell,
      // A compact add button rather than a labelled one: on the dashboard an
      // extended button sits over the lower metric tiles and hides a headline
      // number, and covering the numbers the screen exists to show is worse than
      // losing the label. The tooltip and semantics carry the wording instead.
      floatingActionButton: FloatingActionButton(
        // The add button offers what the current destination is about.
        onPressed: () => showAddActionSheet(context, personFirst: onPeopleTab),
        backgroundColor: palette.brand,
        foregroundColor: palette.textOnBrand,
        elevation: 3,
        tooltip: localizations.addTitle,
        child: const Icon(Icons.add, size: 26),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (int index) => shell.goBranch(
            index,
            // Tapping the active tab returns it to its first screen, which is
            // the behaviour people expect from a bottom bar.
            initialLocation: index == shell.currentIndex,
          ),
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: localizations.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: localizations.navLedger,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: localizations.navPeople,
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_repeat_outlined),
              selectedIcon: const Icon(Icons.event_repeat),
              label: localizations.navObligationsShort,
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_outlined),
              selectedIcon: const Icon(Icons.more_horiz),
              label: localizations.navMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom padding that clears the extended FAB, so the last list row is never
/// hidden behind it.
const double kFabClearance = AppSpacing.massive + AppSpacing.xxl;
