import '../models/log_entry.dart';
import 'log_level.dart';

/// 日志文本解析器
/// 支持多种时间戳格式：
///   YYYY-MM-DD HH:MM:SS.mmm / YYYY-MM-DD HH:MM:SS
///   MM-DD HH:MM:SS.mmm       / MM-DD HH:MM:SS
///   HH:MM:SS.mmm             / HH:MM:SS
///   [YYYY-MM-DD HH:MM:SS.mmm] 等方括号包裹格式
class LogParser {
  // 主格式：时间戳 级别/ [PID] 来源 > 消息
  static final RegExp _fullPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:\.\d{3})?)' // 时间戳
    r'\s+'
    r'([VDIWEF])' // 日志级别
    r'/\s+'
    r'(?:\[(\d+)\]\s+)?' // 可选 PID
    r'(.*)$', // 剩余部分（来源 > 消息）
  );

  // 简化格式：时间戳 级别/ 消息（无PID无来源）
  static final RegExp _simplePattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:\.\d{3})?)' // 时间戳
    r'\s+'
    r'([VDIWEF])' // 日志级别
    r'/\s*'
    r'(.*)$', // 消息
  );
  /// 当前年份（用于补全不含年份的时间戳）
  final int _currentYear = DateTime.now().year;

  /// 上一行是否为有效日志行（用于续行判断）
  bool _lastLineWasLog = false;

  // ─── 多种日期解析格式 ───
  static const _dateFormats = [
    'yyyy-MM-dd HH:mm:ss.SSS',
    'yyyy-MM-dd HH:mm:ss',
    'MM-dd HH:mm:ss.SSS',
    'MM-dd HH:mm:ss',
    'HH:mm:ss.SSS',
    'HH:mm:ss',
  ];

  /// 解析时间戳字符串为 DateTime
  DateTime? _parseDateTime(String ts) {
    // 尝试标准日期时间格式
    for (final fmt in _dateFormats) {
      final dt = _tryParse(ts, fmt);
      if (dt != null) return dt;
    }
    return null;
  }

  DateTime? _tryParse(String ts, String fmt) {
    try {
      // 手动解析，避免 intl 依赖
      final parts = _tokenize(ts, fmt);
      if (parts == null) return null;

      int year = _currentYear;
      int month = 1;
      int day = 1;
      int hour = 0;
      int minute = 0;
      int second = 0;
      int millisecond = 0;

      final tokens = fmt.split(' ');
      int partIdx = 0;

      for (final token in tokens) {
        if (token == 'yyyy-MM-dd' || token == 'MM-dd') {
          final datePart = parts[partIdx++];
          final dateSegments = datePart.split('-');
          if (token == 'yyyy-MM-dd') {
            year = int.parse(dateSegments[0]);
            month = int.parse(dateSegments[1]);
            day = int.parse(dateSegments[2]);
          } else {
            month = int.parse(dateSegments[0]);
            day = int.parse(dateSegments[1]);
          }
        } else if (token == 'HH:mm:ss.SSS' || token == 'HH:mm:ss') {
          final timePart = parts[partIdx++];
          final timeMain = timePart.split('.');
          final timeSegments = timeMain[0].split(':');
          hour = int.parse(timeSegments[0]);
          minute = int.parse(timeSegments[1]);
          second = int.parse(timeSegments[2]);
          if (timeMain.length > 1 && token.contains('SSS')) {
            millisecond = int.parse(timeMain[1].padRight(3, '0').substring(0, 3));
          }
        }
      }

      return DateTime(year, month, day, hour, minute, second, millisecond);
    } catch (_) {
      return null;
    }
  }

  /// 将时间戳字符串按格式拆分为 token 数组
  List<String>? _tokenize(String ts, String fmt) {
    final result = <String>[];
    final fmtTokens = fmt.split(' ');
    final tsTokens = ts.split(' ');

    if (fmtTokens.length != tsTokens.length) return null;

    for (var i = 0; i < fmtTokens.length; i++) {
      final expected = fmtTokens[i];
      final actual = tsTokens[i];
      // 基本校验：长度和分隔符
      if (expected.contains('-') && !actual.contains('-')) return null;
      if (expected.contains(':') && !actual.contains(':')) return null;
      result.add(actual);
    }
    return result;
  }

  /// 解析单行日志文本
  LogEntry parseLine(String line, int lineNumber) {
    // 尝试匹配完整格式
    final fullMatch = _fullPattern.firstMatch(line);
    if (fullMatch != null) {
      _lastLineWasLog = true;
      final timestamp = fullMatch.group(1) ?? '';
      final levelCode = fullMatch.group(2) ?? '?';
      final pid = fullMatch.group(3);
      final rest = fullMatch.group(4) ?? '';

      // 分割来源和消息（按第一个 > 分割）
      final gtIndex = rest.indexOf('>');
      final String? tag;
      final String message;
      if (gtIndex >= 0) {
        tag = rest.substring(0, gtIndex).trim();
        message = rest.substring(gtIndex + 1).trim();
      } else {
        tag = null;
        message = rest.trim();
      }

      return LogEntry(
        lineNumber: lineNumber,
        rawText: line,
        timestamp: timestamp,
        dateTime: _parseDateTime(timestamp),
        level: LogLevel.fromCode(levelCode),
        pid: pid,
        tag: tag,
        message: message,
      );
    }

    // 尝试匹配简化格式
    final simpleMatch = _simplePattern.firstMatch(line);
    if (simpleMatch != null) {
      _lastLineWasLog = true;
      final ts = simpleMatch.group(1) ?? '';
      return LogEntry(
        lineNumber: lineNumber,
        rawText: line,
        timestamp: ts,
        dateTime: _parseDateTime(ts),
        level: LogLevel.fromCode(simpleMatch.group(2) ?? '?'),
        message: simpleMatch.group(3)?.trim() ?? '',
      );
    }

    // 判断是否为续行（堆栈跟踪等）
    final isCont = _lastLineWasLog && _isContinuationLine(line);
    final entry = LogEntry(
      lineNumber: lineNumber,
      rawText: line,
      isContinuation: isCont,
      message: line.trim(),
    );
    // 续行不改变 _lastLineWasLog 状态
    if (!isCont && line.trim().isNotEmpty) {
      _lastLineWasLog = false;
    }
    return entry;
  }

  /// 批量解析
  List<LogEntry> parseLines(List<String> lines) {
    _lastLineWasLog = false;
    final entries = <LogEntry>[];
    for (var i = 0; i < lines.length; i++) {
      entries.add(parseLine(lines[i], i + 1));
    }
    return entries;
  }

  /// 判断是否为续行（堆栈跟踪、缩进行等）
  bool _isContinuationLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (line.startsWith(' ') || line.startsWith('\t')) return true;
    if (trimmed.startsWith('at ') ||
        trimmed.startsWith('Caused by:') ||
        trimmed.startsWith('... ')) {
      return true;
    }
    return false;
  }
}