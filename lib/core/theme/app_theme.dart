import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] for Dhimmah.
///
/// Component themes are configured centrally so screens never restyle a button
/// or a field locally; that is what keeps the product feeling like one app.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final TextTheme text = AppTypography.textTheme(p.textPrimary, p.textSecondary);
    final ColorScheme scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.brand,
      onPrimary: p.textOnBrand,
      primaryContainer: p.brandContainer,
      onPrimaryContainer: p.onBrandContainer,
      secondary: p.gold,
      onSecondary: p.isDark ? BrandInk.onGold : Colors.white,
      secondaryContainer: p.goldContainer,
      onSecondaryContainer: p.gold,
      tertiary: p.owedToMe,
      onTertiary: p.isDark ? BrandInk.onGold : Colors.white,
      error: p.overdue,
      onError: Colors.white,
      errorContainer: p.overdueContainer,
      onErrorContainer: p.overdue,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceMuted,
      surfaceContainerHigh: p.surfaceMuted,
      surfaceContainerHighest: p.surfaceRaised,
      onSurfaceVariant: p.textSecondary,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: p.shadow,
      scrim: p.overlay,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.surface,
      inversePrimary: p.brandStrong,
    );

    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: AppRadius.rMd,
      borderSide: BorderSide(color: p.borderStrong, width: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[p],

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(color: p.border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listRow,
        iconColor: p.textSecondary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: AppSpacing.md,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary),
        labelStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: p.brand),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: p.overdue),
        border: fieldBorder,
        enabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.brand, width: 1.8),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.overdue, width: 1.4),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.overdue, width: 1.8),
        ),
        disabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.border.withValues(alpha: 0.5)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.textOnBrand,
          disabledBackgroundColor: p.borderStrong,
          disabledForegroundColor: p.textTertiary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          textStyle: text.labelLarge,
          side: BorderSide(color: p.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textSecondary,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
        ),
      ),

      iconTheme: IconThemeData(color: p.textSecondary, size: 22),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceMuted,
        selectedColor: p.brandContainer,
        disabledColor: p.surfaceMuted,
        side: BorderSide(color: p.border),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rPill),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: p.borderStrong),
          ),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppSpacing.minTouchTarget),
          ),
          // Selection is a UI state, not a brand moment, so it uses the same
          // tint as the filter chips rather than the gold accent.
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.brandContainer;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.onBrandContainer;
            return p.textSecondary;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.onBrandContainer;
            return p.textSecondary;
          }),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surfaceRaised,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxl,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? p.surfaceRaised : BrandInk.snackBar,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: p.isDark ? p.brandStrong : BrandInk.snackBarAction,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            color: selected ? p.brand : p.textTertiary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? p.brand : p.textTertiary,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.textSecondary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: p.border,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.brand, width: 2.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return p.isDark ? p.textTertiary : p.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return p.borderStrong;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return p.borderStrong;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return Colors.transparent;
        }),
        side: BorderSide(color: p.borderStrong, width: 1.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.brand,
        inactiveTrackColor: p.border,
        thumbColor: p.brand,
        overlayColor: p.brand.withValues(alpha: 0.12),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: p.surfaceMuted,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rMd,
          side: BorderSide(color: p.border),
        ),
        textStyle: text.bodyMedium,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceRaised : BrandInk.snackBar,
          borderRadius: AppRadius.rSm,
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.brand,
        headerForegroundColor: p.textOnBrand,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        dayShape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: AppRadius.rSm),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// A couple of raw values that only the theme layer needs.
abstract final class BrandInk {
  const BrandInk._();
  static const Color snackBar = Color(0xFF0F2521);
  static const Color snackBarAction = Color(0xFF88D5C6);
  static const Color onGold = Color(0xFF241C05);
}
