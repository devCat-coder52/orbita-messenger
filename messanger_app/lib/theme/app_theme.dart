import 'package:flutter/material.dart';

/// Единая система токенов цветов для светлой и тёмной темы.
///
/// Правило использования: в виджетах запрещены `Colors.white`,
/// `Colors.grey.shadeX` и константы напрямую — вместо них берите токен
/// из `context.app` (см. [AppTokens.of]).
abstract final class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceVariant,
    required this.bubbleMine,
    required this.bubbleEditing,
    required this.bubbleTheirs,
    required this.headerBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnHeader,
    required this.hint,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.divider,
    required this.badgeUnread,
    required this.textOnAccent,
    required this.error,
    required this.errorBackground,
    required this.success,
    required this.splashOrbitMuted,
    required this.splashForeground,
    required this.splashGlow,
    required this.splashSubtitle,
    required this.overlayDark,
    required this.shadow,
  });

  factory AppTokens.of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  // --- Основные поверхности -------------------------------------------------
  final Color scaffoldBackground; // фон экранов
  final Color surface; // карточки, листы
  final Color surfaceVariant; // вторичные панели (поле ввода, reply-превью)
  final Color bubbleMine; // пузырёк исходящего сообщения
  final Color bubbleEditing; // пузырёк в режиме редактирования
  final Color bubbleTheirs; // пузырёк входящего сообщения
  final Color headerBackground; // градиент шапки чата / AppBar

  // --- Текст -----------------------------------------------------------------
  final Color textPrimary; // основной текст
  final Color textSecondary; // второстепенный (подписи, время)
  final Color textOnHeader; // текст поверх градиентной шапки
  final Color hint; // плейсхолдеры, неактивные иконки

  // --- Акценты ---------------------------------------------------------------
  final Color primary; // фирменный синий-тёмный
  final Color secondary; // акцент (кнопки отправки, ссылки)
  final Color accent; // яркий акцент (онлайн-точка, FAB)
  final Color divider; // разделители
  final Color badgeUnread; // фон бейджа непрочитанных
  final Color textOnAccent; // текст/иконки на акцентном фоне

  // --- Статусы ---------------------------------------------------------------
  final Color error;
  final Color errorBackground;
  final Color success;

  // --- Специфика -------------------------------------------------------------
  final Color splashOrbitMuted;
  final Color splashForeground;
  final Color splashGlow;
  final Color splashSubtitle;
  final Color overlayDark; // затемнение поверх фото/видео
  final Color shadow; // базовый цвет тени

  /// Тени карточек/пузырьков — в тёмной теме почти невидимы.
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadow.withValues(alpha: 0.08),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Светлые токены — соответствуют прежней палитре приложения.
final class LightTokens extends AppTokens {
  const LightTokens()
    : super(
        scaffoldBackground: const Color(0xFFF5F7FA),
        surface: Colors.white,
        surfaceVariant: const Color(0xFFECF1F5),
        bubbleMine: const Color(0xFFE3F2FD),
        bubbleEditing: const Color(0xFFB3E5FC),
        bubbleTheirs: const Color(0xFFE7EAEF),
        headerBackground: const Color(0xFF2C3E50),
        textPrimary: const Color(0xFF1B2733),
        textSecondary: const Color(0xFF507192),
        textOnHeader: Colors.white,
        hint: const Color(0xFF9AAAB8),
        primary: const Color(0xFF2C3E50),
        secondary: const Color(0xFF3498DB),
        accent: const Color(0xFF2196F3),
        divider: const Color(0xFFE1E7ED),
        badgeUnread: const Color(0xFF3498DB),
        textOnAccent: Colors.white,
        error: const Color(0xFFB71C1C),
        errorBackground: const Color(0xFFFFEBEE),
        success: const Color(0xFF2E7D32),
        splashOrbitMuted: const Color(0xFF91A5B8),
        splashForeground: const Color(0xFFF7FAFC),
        splashGlow: const Color(0x215B7186),
        splashSubtitle: const Color(0xFFB9C7D3),
        overlayDark: const Color(0x99000000),
        shadow: Colors.black,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) =>
      other is! LightTokens ? this : LightTokens();

  @override
  AppTokens copyWith() => this;
}

/// Тёмные токены: приглушённые сине-графитовые поверхности,
/// пузырьки и акценты подобраны по контрасту (WCAG AA).
final class DarkTokens extends AppTokens {
  const DarkTokens()
    : super(
        scaffoldBackground: const Color(0xFF10151C),
        surface: const Color(0xFF1A222C),
        surfaceVariant: const Color(0xFF232E3B),
        bubbleMine: const Color(0xFF1E3A5F),
        bubbleEditing: const Color(0xFF274B6D),
        bubbleTheirs: const Color(0xFF232E3B),
        headerBackground: const Color(0xFF141B24),
        textPrimary: const Color(0xFFE6ECF2),
        textSecondary: const Color(0xFF9FB2C4),
        textOnHeader: const Color(0xFFF2F6FA),
        hint: const Color(0xFF6C7E8F),
        primary: const Color(0xFF3A5068),
        secondary: const Color(0xFF5BA8DC),
        accent: const Color(0xFF4FA3E8),
        divider: const Color(0xFF2A3644),
        badgeUnread: const Color(0xFF3D87C4),
        textOnAccent: Colors.white,
        error: const Color(0xFFEF5350),
        errorBackground: const Color(0xFF3B1F22),
        success: const Color(0xFF66BB6A),
        splashOrbitMuted: const Color(0xFF45596E),
        splashForeground: const Color(0xFFDDE7EF),
        splashGlow: const Color(0x2A5B7186),
        splashSubtitle: const Color(0xFF8CA0B3),
        overlayDark: const Color(0xD9000000),
        shadow: Colors.black,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) =>
      other is! DarkTokens ? this : DarkTokens();

  @override
  AppTokens copyWith() => this;
}

/// Утилита доступа: `context.app.textPrimary`.
extension AppTokensContext on BuildContext {
  AppTokens get app => AppTokens.of(this);
}

/// Строит полную [ThemeData] из набора токенов.
ThemeData buildTheme(Brightness brightness, AppTokens tokens) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2C3E50),
    brightness: brightness,
    primary: tokens.primary,
    secondary: tokens.secondary,
    surface: tokens.surface,
    error: tokens.error,
  );

  final baseText = ThemeData(
    useMaterial3: true,
    brightness: brightness,
  ).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.scaffoldBackground,
    canvasColor: tokens.scaffoldBackground,
    colorScheme: scheme,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.headerBackground,
      foregroundColor: tokens.textOnHeader,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: baseText.titleLarge?.copyWith(
        fontSize: 20,
        color: tokens.textOnHeader,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: tokens.textOnHeader),
    ),
    textTheme: baseText.apply(
      bodyColor: tokens.textPrimary,
      displayColor: tokens.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.textOnAccent,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.secondary),
    ),
    iconTheme: IconThemeData(color: tokens.textSecondary),
    dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      hintStyle: TextStyle(color: tokens.hint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: isDark ? 0 : 2,
      shadowColor: tokens.shadow.withValues(alpha: 0.1),
      color: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.secondary,
      foregroundColor: tokens.textOnAccent,
      elevation: 4,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.textSecondary,
      textColor: tokens.textPrimary,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      modalBarrierColor: tokens.overlayDark,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      titleTextStyle: baseText.titleLarge?.copyWith(color: tokens.textPrimary),
      contentTextStyle: baseText.bodyMedium?.copyWith(
        color: tokens.textSecondary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? tokens.surfaceVariant : tokens.primary,
      contentTextStyle: TextStyle(color: tokens.textOnAccent),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.surface,
      textStyle: baseText.bodyMedium?.copyWith(color: tokens.textPrimary),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.secondary,
      linearTrackColor: tokens.divider,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: tokens.textPrimary, fontSize: 12),
    ),
  );
}

/// Публичные темы для MaterialApp.
abstract final class AppThemes {
  static ThemeData light() => buildTheme(Brightness.light, LightTokens());
  static ThemeData dark() => buildTheme(Brightness.dark, DarkTokens());
}
