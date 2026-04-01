import 'package:flutter/material.dart';

/// 移动端主题颜色扩展（ThemeExtension）
/// 支持亮色/暗色主题动态切换，通过 MobileColors.of(context) 在 build() 中获取当前主题颜色。
///
/// 用法：
/// ```dart
/// final colors = MobileColors.of(context);
/// Container(color: colors.background)
/// Text('hello', style: TextStyle(color: colors.textPrimary))
/// ```
class MobileColors extends ThemeExtension<MobileColors> {
  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  const MobileColors({
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
  });

  /// 亮色主题颜色
  static const light = MobileColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFFC7C7CC),
    divider: Color(0xFFE8E8E8),
  );

  /// 暗色主题颜色
  static const dark = MobileColors(
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    cardBackground: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF48484A),
    divider: Color(0xFF2C2C2E),
  );

  /// 从当前 BuildContext 读取主题颜色，找不到时回退到 light。
  static MobileColors of(BuildContext context) =>
      Theme.of(context).extension<MobileColors>() ?? light;

  @override
  MobileColors copyWith({
    Color? background,
    Color? surface,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
  }) {
    return MobileColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
    );
  }

  @override
  MobileColors lerp(ThemeExtension<MobileColors>? other, double t) {
    if (other is! MobileColors) return this;
    return MobileColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
