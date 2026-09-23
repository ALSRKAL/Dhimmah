import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/services/monthly_report_builder.dart';
import '../../l10n/generated/app_localizations.dart';

/// The monthly report.
///
/// Cards carry the numbers and one chart carries the shape of the last few
/// months. No chart is drawn when there is nothing to compare, because an empty
/// axis looks like a failure rather than an absence of data.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  AppCurrency? _currency;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final List<AppCurrency> currencies = ref.watch(currenciesInUseProvider);
    final AppCurrency currency = _currency ?? currencies.first;

    if (_currency == null || !currencies.contains(_currency)) {
      _currency = currency;
    }

    final AsyncValue<MonthlyReport> report =
        ref.watch(monthlyReportProvider((year: _month.year, month: _month.month, currency: currency)));

    return Scaffold(
      appBar: AppBar(title: Text(localizations.reportMonthlyTitle)),
      body: AsyncValueView<MonthlyReport>(
        value: report,
        onRetry: () => ref.invalidate(
          monthlyReportProvider(
            (year: _month.year, month: _month.month, currency: currency),
          ),
        ),
        loading: const ListSkeleton(),
        builder: (BuildContext context, MonthlyReport data) {
          final bool isFuture = data.isFuture(ref.watch(todayProvider));
          // The insight counts what is outstanding today, not at month end, so
          // it says the same thing the dashboard does.
          final DateTime asOf = ref.watch(todayProvider);
          final List<DebtView> views =
              ref.watch(debtViewsProvider).value ?? const <DebtView>[];
          final int overdueCount = views
              .where((DebtView v) => v.status == DebtLifecycleStatus.overdue)
              .length;
          final int dueSoonCount = views
              .where((DebtView v) =>
                  v.status == DebtLifecycleStatus.dueSoon ||
                  v.status == DebtLifecycleStatus.dueToday)
              .length;
          final bool isCurrentMonth = _month.year == asOf.year &&
              _month.month == asOf.month;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.massive,
            ),
            children: <Widget>[
              _MonthPicker(
                month: _month,
                onChanged: (DateTime value) => setState(() => _month = value),
                currencies: currencies,
                currency: currency,
                onCurrencyChanged: (AppCurrency value) =>
                    setState(() => _currency = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isFuture)
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(localizations.reportFutureMonth)),
                    ],
                  ),
                )
              else if (data.isEmpty)
                EmptyState(
                  compact: true,
                  title: localizations.reportEmptyTitle,
                  body: localizations.reportEmptyBody,
                )
              else ...<Widget>[
                _HighlightCard(report: data),
                const SizedBox(height: AppSpacing.md),
                _InsightLine(
                  insight: monthlyInsightFor(
                    data,
                    overdueCount: overdueCount,
                    dueSoonCount: dueSoonCount,
                    isCurrentMonth: isCurrentMonth,
                  ),
                  overdueCount: overdueCount,
                  dueSoonCount: dueSoonCount,
                  closedCount: data.closedDebts,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ReportGrid(report: data),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: localizations.reportTrend(6)),
                _TrendChart(report: data),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: localizations.reportCurrentPosition),
                _PositionCard(report: data),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.onChanged,
    required this.currencies,
    required this.currency,
    required this.onCurrencyChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final List<AppCurrency> currencies;
  final AppCurrency currency;
  final ValueChanged<AppCurrency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: () =>
                onChanged(addMonths(month, -1)),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.formatting.dates.monthYear(month),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
            icon: const Icon(Icons.chevron_right, size: 22),
            // The future has no report, so the control stops at this month.
            onPressed: month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                ? () => onChanged(addMonths(month, 1))
                : null,
          ),
          if (currencies.length > 1) ...<Widget>[
            Container(
              width: 1,
              height: 24,
              color: palette.border,
            ),
            const SizedBox(width: AppSpacing.sm),
            PopupMenuButton<AppCurrency>(
              initialValue: currency,
              tooltip: AppLocalizations.of(context).fieldCurrency,
              onSelected: onCurrencyChanged,
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<AppCurrency>>[
                for (final AppCurrency option in currencies)
                  PopupMenuItem<AppCurrency>(
                    value: option,
                    child: Text('${option.code} · ${option.symbol}'),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(currency.code, style: theme.textTheme.labelLarge),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The headline: what moved this month.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppCurrency currency = report.currency;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.reportSettled,
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.formatting.amount(Money(report.settledMinor, currency)),
            style: theme.textTheme.displaySmall?.copyWith(
              color: palette.settled,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: localizations.reportReceived,
                  money: Money(report.receivedMinor, currency),
                  color: palette.owedToMe,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  label: localizations.reportPaidOut,
                  money: Money(report.paidOutMinor, currency),
                  color: palette.iOwe,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.money,
    required this.color,
    required this.icon,
  });

  final String label;
  final Money money;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        MoneyText(
          money,
          color: color,
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _ReportGrid extends StatelessWidget {
  const _ReportGrid({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final AppCurrency currency = report.currency;

    final List<_GridItem> items = <_GridItem>[
      _GridItem(
        label: localizations.reportNewDebts,
        value: context.formatting.amount(Money(report.newDebtMinor, currency)),
        icon: Icons.add_circle_outline,
        color: palette.brand,
      ),
      _GridItem(
        label: localizations.reportObligations,
        value: context.formatting.amount(Money(report.obligationsMinor, currency)),
        icon: Icons.event_repeat_outlined,
        color: palette.brand,
      ),
      _GridItem(
        label: localizations.reportOverdue,
        value: context.formatting.amount(Money(report.overdueMinor, currency)),
        icon: Icons.error_outline,
        color: palette.overdue,
      ),
      _GridItem(
        label: localizations.reportClosedDebts,
        value: context.formatting.count(report.closedDebts),
        icon: Icons.check_circle_outline,
        color: palette.settled,
      ),
      _GridItem(
        label: localizations.reportActiveDebts,
        value: context.formatting.count(report.activeDebts),
        icon: Icons.pending_outlined,
        color: palette.neutralStatus,
      ),
      _GridItem(
        label: localizations.reportPeopleCount,
        value: context.formatting.count(report.peopleCount),
        icon: Icons.people_outline,
        color: palette.neutralStatus,
      ),
    ];

    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(child: _GridTile(item: items[i])),
                const SizedBox(width: AppSpacing.md),
                if (i + 1 < items.length)
                  Expanded(child: _GridTile(item: items[i + 1]))
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}

class _GridItem {
  const _GridItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.item});

  final _GridItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(item.icon, size: 15, color: item.color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A grouped bar chart of paid versus new debt over the last few months.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final List<MonthlyTrendPoint> points = report.trend;
    final int maxMinor = points.fold<int>(0, (int previous, MonthlyTrendPoint p) {
      final int local = p.settledMinor > p.newDebtMinor ? p.settledMinor : p.newDebtMinor;
      return local > previous ? local : previous;
    });

    if (maxMinor == 0) {
      return AppCard(
        child: Text(
          localizations.reportEmptyTitle,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final double maxValue = maxMinor / report.currency.minorFactor;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _LegendDot(color: palette.settled, label: localizations.reportTrendSettled),
              const SizedBox(width: AppSpacing.lg),
              _LegendDot(color: palette.brand, label: localizations.reportTrendNewDebt),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.15,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (BarChartGroupData _) => palette.surfaceRaised,
                    getTooltipItem: (
                      BarChartGroupData group,
                      int groupIndex,
                      BarChartRodData rod,
                      int rodIndex,
                    ) {
                      final MonthlyTrendPoint point = points[groupIndex];
                      return BarTooltipItem(
                        '${context.formatting.dates.shortMonthYear(DateTime(point.year, point.month))}\n'
                        '${context.formatting.amount(Money((rod.toY * report.currency.minorFactor).round(), report.currency))}',
                        theme.textTheme.labelMedium ?? const TextStyle(),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (double value, TitleMeta meta) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Text(
                          context.formatting.money.amount(
                            Money(
                              (value * report.currency.minorFactor).round(),
                              report.currency,
                            ),
                            compact: true,
                          ),
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final MonthlyTrendPoint point = points[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.formatting.money
                                .integer(point.month),
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 3,
                  getDrawingHorizontalLine: (double value) => FlLine(
                    color: palette.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: points[i].settledMinor / report.currency.minorFactor,
                          color: palette.settled,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: points[i].newDebtMinor / report.currency.minorFactor,
                          color: palette.brand,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final AppCurrency currency = report.currency;

    return AppCard(
      child: Column(
        children: <Widget>[
          DetailRow(
            icon: Icons.arrow_upward_rounded,
            label: localizations.dashboardIOwe,
            value: context.formatting.amount(Money(report.openIOweMinor, currency)),
            valueColor: palette.iOwe,
          ),
          DetailRow(
            icon: Icons.arrow_downward_rounded,
            label: localizations.dashboardOwedToMe,
            value:
                context.formatting.amount(Money(report.openOwedToMeMinor, currency)),
            valueColor: palette.owedToMe,
          ),
          const AppDivider(),
          const SizedBox(height: AppSpacing.xs),
          DetailRow(
            icon: Icons.balance,
            label: localizations.dashboardNetPosition,
            value: context.formatting
                .amount(Money(report.openOwedToMeMinor - report.openIOweMinor, currency)),
            valueColor: palette.textPrimary,
          ),
        ],
      ),
    );
  }
}

/// One true sentence about the month.
///
/// Built from the report's own figures. It is deliberately not a chat message or
/// a guess: it names the thing the user should act on, or confirms there is
/// nothing to act on.
class _InsightLine extends StatelessWidget {
  const _InsightLine({
    required this.insight,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.closedCount,
  });

  final MonthlyInsight insight;
  final int overdueCount;
  final int dueSoonCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final (IconData icon, Color color, String text) = switch (insight) {
      MonthlyInsight.overdue => (
          Icons.error_outline,
          palette.overdue,
          localizations.reportInsightOverdue(overdueCount),
        ),
      MonthlyInsight.upcomingSoon => (
          Icons.schedule_outlined,
          palette.dueSoon,
          localizations.reportInsightUpcoming(dueSoonCount),
        ),
      MonthlyInsight.manyClosed => (
          Icons.check_circle_outline,
          palette.settled,
          localizations.reportInsightClosed(closedCount),
        ),
      MonthlyInsight.allClear => (
          Icons.verified_outlined,
          palette.settled,
          localizations.reportInsightAllClear,
        ),
      MonthlyInsight.quiet => (
          Icons.info_outline,
          palette.textSecondary,
          localizations.reportInsightQuiet,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.16 : 0.09),
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
