import 'package:flutter/material.dart';

import '../models/log_entry.dart';

/// 单条日志行展示组件 — 极致紧凑布局
class LogLineWidget extends StatelessWidget {
  final LogEntry entry;
  final bool isDark;
  final VoidCallback? onTap;

  const LogLineWidget({
    super.key,
    required this.entry,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor =
        isDark ? entry.level.darkColor : entry.level.lightColor;

    if (entry.isContinuation) {
      return _buildContinuationLine(levelColor, isDark);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
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
            // 行号 + 级别 合并为一列
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
            // 主要内容（时间戳 + 来源 + 消息）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.timestamp != null)
                    Text(
                      entry.timestamp!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  if (entry.sourceInfo.isNotEmpty)
                    Text(
                      entry.sourceInfo,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFF64B5F6)
                            : const Color(0xFF1565C0),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                    ),
                  if (entry.message.isNotEmpty)
                    Text(
                      entry.message,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.35,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.visible,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinuationLine(Color levelColor, bool isDark) {
    return Container(
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
            child: Text(
              entry.rawText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                height: 1.3,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              maxLines: 5,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
