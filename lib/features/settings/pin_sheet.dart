import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/security/pin_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/feedback.dart';
import '../../l10n/generated/app_localizations.dart';

/// Asks for the PIN and returns whether it was correct.
Future<bool> verifyPin(BuildContext context, WidgetRef ref) async {
  final bool? ok = await showAppSheet<bool>(
    context,
    isScrollControlled: false,
    child: const PinSheet(mode: PinSheetMode.verify),
  );
  return ok ?? false;
}

/// Creates a new PIN. Returns true once one has been stored.
Future<bool> createPin(BuildContext context, WidgetRef ref) async {
  final bool? ok = await showAppSheet<bool>(
    context,
    isScrollControlled: false,
    child: const PinSheet(mode: PinSheetMode.create),
  );
  return ok ?? false;
}

/// Changes the PIN, verifying the current one first.
Future<bool> changePin(BuildContext context, WidgetRef ref) async {
  final AppLocalizations localizations = AppLocalizations.of(context);
  await showAppSheet<void>(
    context,
    isScrollControlled: false,
    child: const PinSheet(mode: PinSheetMode.change),
  );
  if (!context.mounted) return false;
  AppFeedback.info(context, AppLocalizations.of(context).lockPinUpdated);
  assert(localizations.appName.isNotEmpty);
  return true;
}

enum PinSheetMode { create, verify, change }

/// A four-digit PIN pad.
///
/// A custom keypad rather than a text field: it is larger, it needs no keyboard
/// permission, and on iOS it stops the PIN from being offered to the system
/// keyboard's autofill.
class PinSheet extends ConsumerStatefulWidget {
  const PinSheet({required this.mode, super.key});

  final PinSheetMode mode;

  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet> {
  final List<int> _digits = <int>[];
  int? _confirming;
  String? _error;
  bool _busy = false;

  /// For [PinSheetMode.change], the PIN stage we are on.
  bool _pastCurrent = false;

  int get _length => PinService.pinLength;

  String get _title {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return switch (widget.mode) {
      PinSheetMode.create =>
        _confirming == null
            ? localizations.lockCreatePin(_length)
            : localizations.lockConfirmPin,
      PinSheetMode.verify => localizations.lockEnterPin,
      PinSheetMode.change =>
        _pastCurrent ? localizations.lockNewPin : localizations.lockCurrentPin,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final AppLocalizations localizations = AppLocalizations.of(context);

    return AppSheet(
      title: _title,
      showCloseButton: widget.mode != PinSheetMode.verify,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < _length; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length
                        ? palette.brand
                        : palette.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 22,
            child: _error == null
                ? null
                : Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: palette.overdue),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Keypad(
            onDigit: _busy ? null : _pushDigit,
            onBackspace: _busy ? null : _popDigit,
          ),
          if (widget.mode != PinSheetMode.verify) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.settingsPrivacyNote,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }

  void _pushDigit(int digit) {
    if (_digits.length >= _length) return;
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    if (_digits.length == _length) _submit();
  }

  void _popDigit() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  Future<void> _submit() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final PinService service = ref.read(pinServiceProvider);
    final String pin = _digits.join();

    setState(() => _busy = true);

    switch (widget.mode) {
      case PinSheetMode.verify:
        final PinVerification result = await service.verify(pin);
        if (!mounted) return;
        if (result.accepted) {
          Navigator.of(context).pop(true);
          return;
        }
        setState(() {
          _busy = false;
          _digits.clear();
          _error = result.isLockedOut
              ? localizations.lockTooManyAttempts
              : localizations.lockWrongPin;
        });

      case PinSheetMode.change:
        if (!_pastCurrent) {
          final PinVerification result = await service.verify(pin);
          if (!mounted) return;
          if (!result.accepted) {
            setState(() {
              _busy = false;
              _digits.clear();
              _error = localizations.lockWrongPin;
            });
            return;
          }
          setState(() {
            _busy = false;
            _pastCurrent = true;
            _digits.clear();
            _confirming = null;
          });
          return;
        }
        await _handleCreate(pin, localizations);

      case PinSheetMode.create:
        await _handleCreate(pin, localizations);
    }
  }

  Future<void> _handleCreate(String pin, AppLocalizations localizations) async {
    final PinService service = ref.read(pinServiceProvider);
    final int? first = _confirming;
    if (first == null) {
      setState(() {
        _busy = false;
        _confirming = int.parse(pin);
        _digits.clear();
      });
      return;
    }
    if (first != int.parse(pin)) {
      setState(() {
        _busy = false;
        _confirming = null;
        _digits.clear();
        _error = localizations.lockPinMismatch;
      });
      return;
    }
    await service.setPin(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<int>? onDigit;
  final VoidCallback? onBackspace;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return SizedBox(
        width: 72,
        height: 60,
        child: Material(
          color: palette.surfaceMuted,
          borderRadius: AppRadius.rMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: child ??
                  Text(
                    label,
                    style: theme.textTheme.headlineSmall,
                  ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final List<String> row in <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String digit in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: key(
                      digit,
                      onTap: onDigit == null
                          ? null
                          : () => onDigit!(int.parse(digit)),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: SizedBox(width: 72, height: 60),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: key(
                '0',
                onTap: onDigit == null ? null : () => onDigit!(0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: key(
                '',
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
