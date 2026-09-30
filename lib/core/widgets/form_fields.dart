import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../money/currency.dart';
import '../money/region_currency.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/money_input.dart';
import 'directional_field.dart';

/// A labelled text field with consistent spacing and error presentation.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.formatters,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label),
        // The text's own direction, and a caret that stays where it is put.
        DirectionalField(
          controller: controller,
          builder: (BuildContext context, FieldLayout field) => TextFormField(
            controller: field.controller,
            textDirection: field.direction,
            textAlign: field.align,
            onTap: field.onTap,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLines: obscureText ? 1 : maxLines,
            minLines: maxLines > 1 ? 2 : null,
            obscureText: obscureText,
            maxLength: maxLength,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            inputFormatters: formatters,
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              helperText: helperText,
              counterText: '',
              prefixIcon:
                  prefixIcon == null ? null : Icon(prefixIcon, size: 20),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// The small label that sits above every field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The amount input.
///
/// Amounts are typed the way people write them — with a decimal separator, in
/// either numbering system — and converted to integer minor units on the way out.
/// Nothing here ever produces a `double` that could round a balance wrong.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.label,
    required this.currency,
    required this.onChanged,
    this.initialMinor,
    this.controller,
    this.autofocus = false,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  final String label;
  final AppCurrency currency;
  final ValueChanged<int> onChanged;
  final int? initialMinor;
  final TextEditingController? controller;
  final bool autofocus;
  final String? errorText;
  final bool enabled;

  /// Taken when a save has to send the caret to this field.
  final FocusNode? focusNode;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        TextEditingController(
          text: widget.initialMinor == null
              ? ''
              : formatMinorForInput(widget.initialMinor!, widget.currency),
        );
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    final int? minor = parseAmountToMinor(_controller.text, widget.currency);
    if (minor != null && minor > 0) {
      if (_error != null) setState(() => _error = null);
      widget.onChanged(minor);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(widget.label),
        // An amount is written left to right in both languages. It used to
        // take the app's direction, so in Arabic tapping the field beside the
        // digits put the caret before the first one.
        DirectionalField(
          controller: _controller,
          direction: TextDirection.ltr,
          builder: (BuildContext context, FieldLayout field) => TextFormField(
            controller: field.controller,
            textDirection: field.direction,
            textAlign: field.align,
            onTap: field.onTap,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: theme.textTheme.headlineSmall,
            inputFormatters: <TextInputFormatter>[
              // Includes Arabic-Indic (٠-٩) and extended Arabic-Indic (۰-۹)
              // digits: the parser normalises them, and an Arabic keyboard
              // types them by default, so filtering them out here meant the
              // field silently deleted every character a user on that keyboard
              // typed.
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9.,\u066B\u066C\s]'),
              ),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              hintText: '0',
              errorText: widget.errorText ?? _error,
              // The symbol sits inline before the digits rather than in the
              // icon slot, so the amount reads as one phrase: "₹ 12,000".
              prefix: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: Text(
                  widget.currency.symbolFor(isDefaultCurrency: true),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              // A plain label, not a button: the currency is chosen by the
              // field below, and a control that only explains itself is a false
              // affordance.
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    widget.currency.code,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.placeholder,
    this.clearable = false,
    this.errorText,
    this.icon = Icons.calendar_today_outlined,
    this.enabled = true,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? placeholder;
  final bool clearable;
  final String? errorText;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label),
        InkWell(
          borderRadius: AppRadius.rMd,
          onTap: enabled ? () => _pick(context) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: errorText,
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: clearable && hasValue
                  ? IconButton(
                      tooltip: localizations.actionClear,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onChanged(null),
                    )
                  : null,
            ),
            child: Text(
              hasValue
                  ? context.formatting.date(value!)
                  : (placeholder ?? localizations.chooseOption),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasValue ? palette.textPrimary : palette.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime first = firstDate ?? DateTime(now.year - 30);
    final DateTime last = lastDate ?? DateTime(now.year + 30);
    final DateTime initial = value ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onChanged(picked);
  }
}

class OptionField<T> extends StatelessWidget {
  const OptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.subtitleOf,
    this.title,
    this.icon = Icons.tune,
    this.errorText,
    super.key,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final IconData Function(T option)? iconOf;

  /// A second line for an option in the sheet, or null for one that needs none.
  final String? Function(T option)? subtitleOf;
  final ValueChanged<T> onChanged;
  final String? title;
  final IconData icon;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label),
        InkWell(
          borderRadius: AppRadius.rMd,
          onTap: () => _pick(context),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: errorText,
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: const Icon(Icons.expand_more, size: 20),
            ),
            child: Text(labelOf(value), style: theme.textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final T? picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => OptionSheet<T>(
        title: title ?? label,
        value: value,
        options: options,
        labelOf: labelOf,
        iconOf: iconOf,
        subtitleOf: subtitleOf,
      ),
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}

/// The currency of a record.
///
/// [suggested] — the currency of the place the phone is in, when there is one
/// — comes first in the list and says so, as it does wherever a currency is
/// picked. It is only offered: [value] is what the record has.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    required this.value,
    required this.onChanged,
    this.suggested,
    super.key,
  });

  final AppCurrency value;
  final AppCurrency? suggested;
  final ValueChanged<AppCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return OptionField<AppCurrency>(
      label: localizations.fieldCurrency,
      value: value,
      options: currenciesWithFirst(suggested),
      labelOf: (AppCurrency currency) => currency.codeAndSymbol,
      subtitleOf: (AppCurrency currency) => currency == suggested
          ? localizations.currencySuggestedForRegion
          : null,
      iconOf: (AppCurrency _) => Icons.payments_outlined,
      title: localizations.fieldCurrency,
      icon: Icons.payments_outlined,
      onChanged: onChanged,
    );
  }
}

/// The list inside an [OptionField]'s sheet. Also used directly by pickers that
/// need to show more than a label.
class OptionSheet<T> extends StatelessWidget {
  const OptionSheet({
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    this.iconOf,
    this.subtitleOf,
    super.key,
  });

  final String title;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final IconData Function(T option)? iconOf;
  /// A second line for an option, or null for an option that needs none.
  final String? Function(T option)? subtitleOf;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final T option = options[index];
                  final bool selected = option == value;
                  final String? subtitle = subtitleOf?.call(option);
                  return ListTile(
                    leading: iconOf == null
                        ? null
                        : Icon(
                            iconOf!(option),
                            color: selected ? palette.brand : palette.textSecondary,
                          ),
                    title: Text(
                      labelOf(option),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: selected ? palette.brand : palette.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: selected
                        ? Icon(Icons.check, color: palette.brand, size: 20)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A two-or-more option toggle that stays readable at small widths.
class SegmentedField<T> extends StatelessWidget {
  const SegmentedField({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    super.key,
  });

  final String? label;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final IconData Function(T option)? iconOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget segmented = SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: <ButtonSegment<T>>[
          for (final T option in options)
            ButtonSegment<T>(
              value: option,
              label: Text(labelOf(option)),
              icon: iconOf == null ? null : Icon(iconOf!(option), size: 18),
            ),
        ],
        selected: <T>{value},
        showSelectedIcon: false,
        onSelectionChanged: (Set<T> selection) {
          if (selection.isNotEmpty) onChanged(selection.first);
        },
      ),
    );
    if (label == null) return segmented;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label!),
        segmented,
      ],
    );
  }
}

/// Multi-select for reminder lead times.
///
/// Rendered as a wrap of filter chips so the whole set is visible at once — the
/// spec allows more than one reminder on a record, and a multi-select menu would
/// hide that.
class ReminderLeadsField extends StatelessWidget {
  const ReminderLeadsField({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.unavailableReason,
    super.key,
  });

  final String label;
  final List<ReminderLead> selected;
  final ValueChanged<List<ReminderLead>> onChanged;

  /// Why a chosen reminder will not reach the phone, when that is the case.
  ///
  /// "A reminder is set" and "a reminder will arrive" are different statements,
  /// and a form that offers the first while the second is impossible misleads by
  /// omission. The reason is stated here, where the choice is made.
  final String? unavailableReason;

  static const List<ReminderLead> _choices = <ReminderLead>[
    ReminderLead.onDueDate,
    ReminderLead.oneDayBefore,
    ReminderLead.twoDaysBefore,
    ReminderLead.threeDaysBefore,
    ReminderLead.oneWeekBefore,
    ReminderLead.twoWeeksBefore,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final ReminderLead lead in _choices)
              FilterChip(
                label: Text(lead.label(localizations)),
                selected: selected.contains(lead),
                onSelected: (bool isSelected) {
                  final List<ReminderLead> next =
                      List<ReminderLead>.of(selected);
                  if (isSelected) {
                    next.add(lead);
                  } else {
                    next.remove(lead);
                  }
                  onChanged(ReminderLead.sorted(next));
                },
              ),
          ],
        ),
        if (unavailableReason != null && selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.notifications_off_outlined,
                  size: 16,
                  color: palette.dueSoon,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    unavailableReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.dueSoon,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
