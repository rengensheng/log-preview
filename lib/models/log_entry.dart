import '../core/log_level.dart';

/// 单条日志条目模型
class LogEntry {
  /// 行号（从1开始）
  final int lineNumber;

  /// 原始文本行
  final String rawText;

  /// 时间戳字符串
  final String? timestamp;

  /// 解析后的日期时间（可能为 null，如续行或无时间戳行）
  final DateTime? dateTime;

  /// 日志级别
  final LogLevel level;

  /// 进程ID
  final String? pid;

  /// 来源标签（类名.方法名(文件:行)）
  final String? tag;

  /// 日志消息正文
  final String message;

  /// 是否为续行（无时间戳的堆栈跟踪等）
  final bool isContinuation;

  const LogEntry({
    required this.lineNumber,
    required this.rawText,
    this.timestamp,
    this.dateTime,
    this.level = LogLevel.unknown,
    this.pid,
    this.tag,
    this.message = '',
    this.isContinuation = false,
  });

  /// 完整来源描述
  String get sourceInfo {
    if (isContinuation) return '';
    final parts = <String>[];
    if (pid != null) parts.add('[$pid]');
    if (tag != null && tag!.isNotEmpty) parts.add(tag!);
    return parts.join(' ');
  }

  @override
  String toString() =>
      'LogEntry(#$lineNumber $level $timestamp ${tag ?? "-"}: $message)';
}
