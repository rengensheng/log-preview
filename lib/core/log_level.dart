import 'package:flutter/material.dart';

/// 日志级别枚举
enum LogLevel {
  verbose('V', 'Verbose'),
  debug('D', 'Debug'),
  info('I', 'Info'),
  warning('W', 'Warning'),
  error('E', 'Error'),
  fatal('F', 'Fatal'),
  unknown('?', 'Unknown');

  final String code;
  final String label;
  const LogLevel(this.code, this.label);

  /// 从字符解析日志级别
  static LogLevel fromCode(String code) {
    for (final level in LogLevel.values) {
      if (level.code == code.toUpperCase()) return level;
    }
    return LogLevel.unknown;
  }

  /// 暗色主题下的颜色
  Color get darkColor => switch (this) {
        LogLevel.verbose => const Color(0xFF757575),
        LogLevel.debug => const Color(0xFF9E9E9E),
        LogLevel.info => const Color(0xFF4FC3F7),
        LogLevel.warning => const Color(0xFFFFB74D),
        LogLevel.error => const Color(0xFFEF5350),
        LogLevel.fatal => const Color(0xFFFF1744),
        LogLevel.unknown => const Color(0xFFBDBDBD),
      };

  /// 亮色主题下的颜色
  Color get lightColor => switch (this) {
        LogLevel.verbose => const Color(0xFF9E9E9E),
        LogLevel.debug => const Color(0xFF757575),
        LogLevel.info => const Color(0xFF1565C0),
        LogLevel.warning => const Color(0xFFE65100),
        LogLevel.error => const Color(0xFFC62828),
        LogLevel.fatal => const Color(0xFFB71C1C),
        LogLevel.unknown => const Color(0xFF616161),
      };
}
