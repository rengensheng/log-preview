import 'package:flutter/material.dart';

import '../models/log_entry.dart';

/// 日志行展示组件 — 支持搜索高亮 + 点击展开/收起
class LogLineWidget extends StatelessWidget {
  final LogEntry entry;
  final bool isDark;
  final String? highlightQuery;
  final bool isCurrentMatch;
  final bool isExpanded;
  final VoidCallback? onTap;

  const LogLineWidget({
    super.key,
    required this.entry,
    required this.isDark,
    this.highlightQuery,
    this.isCurrentMatch = false,
    this.isExpanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = isDark ? entry.level.darkColor : entry.level.lightColor;
    final query = highlightQuery != null && highlightQuery!.isNotEmpty
        ? highlightQuery!.toLowerCase()
        : null;

    // 判断消息是否较长（需要展开按钮）
    final hasLongMessage = entry.message.length > 200 ||
        '\n'.allMatches(entry.message).length > 3;

    if (entry.isContinuation) {
      return _buildContinuationLine(levelColor, isDark, query, hasLongMessage);
    }

    // 展开态背景：轻微不同以示区别
    final bgColor = isExpanded
        ? (isDark
            ? Colors.blueGrey.shade800.withAlpha(40)
            : Colors.blueGrey.shade50.withAlpha(120))
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        color: isCurrentMatch
            ? (isDark
                ? Colors.yellow.shade800.withAlpha(60)
                : Colors.yellow.shade100.withAlpha(180))
            : bgColor,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Text(
                    '${entry.lineNumber}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      height: 1.3,
                      color: isDark ? Colors.white24 : Colors.black38,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    entry.level.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.timestamp != null)
                    _buildHighlightedText(
                      entry.timestamp!,
                      query,
                      TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF2E7D32),
                      ),
                      isDark,
                      maxLines: null,
                    ),
                  if (entry.sourceInfo.isNotEmpty)
                    _buildHighlightedText(
                      entry.sourceInfo,
                      query,
                      TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFF64B5F6)
                            : const Color(0xFF1565C0),
                      ),
                      isDark,
                      maxLines: isExpanded ? null : 3,
                    ),
                  if (entry.message.isNotEmpty)
                    _buildHighlightedText(
                      entry.message,
                      query,
                      TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.35,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      isDark,
                      maxLines: isExpanded ? null : 5,
                    ),
                  // 展开/收起提示
                  if (hasLongMessage)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.unfold_less
                                : Icons.unfold_more,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isExpanded ? '收起' : '展开全文',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String? query,
    TextStyle baseStyle,
    bool isDark, {
    int? maxLines = 5,
  }) {
    if (query == null || query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.visible,
      );
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor:
              isDark ? Colors.yellow.shade700 : Colors.yellow.shade300,
          color: isDark ? Colors.black : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.visible,
    );
  }

  Widget _buildContinuationLine(
      Color levelColor, bool isDark, String? query, bool hasLong) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 28),
            const SizedBox(width: 3),
            Expanded(
              child: _buildHighlightedText(
                entry.rawText,
                query,
                TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  height: 1.3,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                isDark,
                maxLines: isExpanded ? null : 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
