import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_level.dart';
import '../core/log_parser.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../widgets/log_filter_bar.dart';
import '../widgets/log_line_widget.dart';
import '../widgets/log_scroll_bar.dart';

/// 日志查看页 — 展示解析后的日志内容
class LogViewerPage extends StatefulWidget {
  final List<String> lines;
  final String filePath;
  final int fileSize;
  final String? encoding;

  const LogViewerPage({
    super.key,
    required this.lines,
    required this.filePath,
    required this.fileSize,
    this.encoding,
  });

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final _parser = LogParser();
  final _fileService = FileService();
  final _scrollController = ScrollController();

  List<LogEntry> _allEntries = [];
  List<LogEntry> _filteredEntries = [];
  bool _isSearching = false;
  String _searchQuery = '';
  Set<LogLevel> _levelFilter = {};
  DateTime? _dateStart;
  DateTime? _dateEnd;
  int _activeFilterCount = 0;
  bool _isDark = false;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _parseLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll > 200 && _autoScroll) {
      setState(() => _autoScroll = false);
    } else if (maxScroll - currentScroll < 50 && !_autoScroll) {
      setState(() => _autoScroll = true);
    }
  }

  void _parseLogs() {
    _allEntries = _parser.parseLines(widget.lines);
    _applyFilters();
  }

  void _applyFilters() {
    var entries = _allEntries;
    int filterCount = 0;

    // 级别筛选
    if (_levelFilter.isNotEmpty) {
      filterCount++;
      entries = entries.where((e) {
        if (e.isContinuation) return true;
        return _levelFilter.contains(e.level);
      }).toList();
    }

    // 文本搜索
    if (_searchQuery.isNotEmpty) {
      filterCount++;
      final query = _searchQuery.toLowerCase();
      entries = entries.where((e) {
        return e.rawText.toLowerCase().contains(query);
      }).toList();
    }

    // 日期范围筛选
    if (_dateStart != null || _dateEnd != null) {
      filterCount++;
      entries = entries.where((e) {
        if (e.isContinuation) return true; // 续行保留（跟随上一行）
        if (e.dateTime == null) return _dateStart == null && _dateEnd == null;
        if (_dateStart != null && e.dateTime!.isBefore(_dateStart!)) {
          return false;
        }
        if (_dateEnd != null && e.dateTime!.isAfter(_dateEnd!)) {
          return false;
        }
        return true;
      }).toList();
    }

    setState(() {
      _filteredEntries = entries;
      _activeFilterCount = filterCount;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onLevelFilterChanged(Set<LogLevel> levels) {
    _levelFilter = levels;
    _applyFilters();
  }

  void _onStartDateChanged(DateTime? dt) {
    _dateStart = dt;
    _applyFilters();
  }

  void _onEndDateChanged(DateTime? dt) {
    _dateEnd = dt;
    _applyFilters();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      maxScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _shareFile() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        subject: _fileService.fileNameFromPath(widget.filePath),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  void _copyEntry(LogEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.rawText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Map<LogLevel, int> _countByLevel() {
    final counts = <LogLevel, int>{};
    for (final e in _allEntries) {
      if (!e.isContinuation) {
        counts[e.level] = (counts[e.level] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// 日期范围描述
  String get _dateRangeDesc {
    if (_dateStart == null && _dateEnd == null) return '';
    return '${_fmtDt(_dateStart)} — ${_fmtDt(_dateEnd)}';
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '...';
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  String _buildSubtitle(String sizeStr) {
    final base = '${_allEntries.length} 行 · $sizeStr';
    if (widget.encoding != null && widget.encoding != 'utf-8') {
      return '$base  · 编码: ${widget.encoding}';
    }
    return base;
  }
  @override
  Widget build(BuildContext context) {
    final fileName = _fileService.fileNameFromPath(widget.filePath);
    final sizeStr = _fileService.formatFileSize(widget.fileSize);
    final levelCounts = _countByLevel();
    final bg = _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);
    final hasActiveFilter = _activeFilterCount > 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: const TextStyle(fontSize: 16)),
            Text(
              _buildSubtitle(sizeStr),
              style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
        actions: [
          if (levelCounts.isNotEmpty)
            Center(child: _buildLevelSummary(levelCounts)),
          IconButton(
            icon: Icon(_isSearching ? Icons.search_off : Icons.search),
            tooltip: '搜索',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享文件',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索/筛选栏
          if (_isSearching)
            LogFilterBar(
              isDark: _isDark,
              onSearchChanged: _onSearchChanged,
              onLevelFilterChanged: _onLevelFilterChanged,
              onClose: _toggleSearch,
              startDate: _dateStart,
              endDate: _dateEnd,
              onStartDateChanged: _onStartDateChanged,
              onEndDateChanged: _onEndDateChanged,
            ),
          // 筛选结果提示
          if (hasActiveFilter)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color:
                  _isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
              child: Row(
                children: [
                  Text(
                    '筛选: ${_filteredEntries.length} / ${_allEntries.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (_dateRangeDesc.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.date_range, size: 12,
                        color: _isDark ? Colors.white54 : Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _dateRangeDesc,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: _isDark ? Colors.white54 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // 日志列表 + 滚动条
          Expanded(
            child: Stack(
              children: [
                // 日志列表
                _filteredEntries.isEmpty
                    ? Center(
                        child: Text(
                          _allEntries.isEmpty ? '无日志内容' : '无匹配结果',
                          style: TextStyle(
                            color:
                                _isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _filteredEntries.length,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(right: 30),
                        itemBuilder: (context, index) {
                          return LogLineWidget(
                            entry: _filteredEntries[index],
                            isDark: _isDark,
                            onTap: () =>
                                _copyEntry(_filteredEntries[index]),
                          );
                        },
                      ),
                // 可拖拽滚动条（阅读进度条）
                if (_filteredEntries.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: LogScrollBar(
                      controller: _scrollController,
                      itemCount: _filteredEntries.length,
                      isDark: _isDark,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'bottom',
            onPressed: _autoScroll ? null : _scrollToBottom,
            backgroundColor: _autoScroll
                ? (_isDark ? Colors.white12 : Colors.black12)
                : (_isDark ? Colors.blue.shade800 : Colors.blue),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: _autoScroll
                  ? (_isDark ? Colors.white38 : Colors.black38)
                  : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'top',
            onPressed: _scrollToTop,
            backgroundColor: _isDark ? Colors.white12 : Colors.black12,
            child: Icon(Icons.keyboard_arrow_up,
                color: _isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSummary(Map<LogLevel, int> counts) {
    final items = [
      LogLevel.error,
      LogLevel.warning,
      LogLevel.info,
      LogLevel.debug,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((level) {
        final count = counts[level] ?? 0;
        if (count == 0) return const SizedBox.shrink();
        final color = _isDark ? level.darkColor : level.lightColor;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}