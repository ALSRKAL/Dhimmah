import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'empty_state.dart';

/// Renders an [AsyncValue] the same way everywhere.
///
/// Using one widget for loading, error and data means no screen invents its own
/// spinner or forgets the retry path. [onRetry] is required in practice: an error
/// the user cannot act on is just a dead end.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    this.empty,
    this.isEmpty,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  /// Invoked by the error state's retry button. Usually `ref.invalidate(...)`.
  final VoidCallback? onRetry;

  /// Replaces the default skeleton while loading.
  final Widget? loading;

  /// Shown when [isEmpty] reports true.
  final Widget? empty;

  /// Lets a screen treat "loaded, but nothing in it" as an empty state rather
  /// than a list of zero rows.
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData<T>(:final T value) => isEmpty?.call(value) ?? false
          ? (empty ?? const SizedBox.shrink())
          : builder(context, value),
      AsyncError<T>(:final Object error) => ErrorStateView(
          message: _messageFor(context, error),
          retryLabel: onRetry == null ? null : AppLocalizations.of(context).actionRetry,
          onRetry: onRetry,
        ),
      _ => loading ?? const _LoadingIndicator(),
    };
  }

  String _messageFor(BuildContext context, Object error) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    // Raw exception text is never shown: it is written for a developer, not for
    // someone checking whether they paid the rent.
    assert(() {
      debugPrint('AsyncValueView error: $error');
      return true;
    }());
    return localizations.somethingWentWrong;
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.huge),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

/// A skeleton placeholder block, used while a screen's first snapshot loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.height = 16,
    this.width,
    this.radius = AppRadius.sm,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A small shimmer-free placeholder layout for a list that is still loading.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.rows = 5, this.height = 68, super.key});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.screen,
      itemCount: rows,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) =>
          const SkeletonBox(height: 68, radius: AppRadius.lg),
    );
  }
}
