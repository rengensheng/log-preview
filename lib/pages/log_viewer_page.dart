import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_level.dart';
import '../core/log_parser.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../widgets/log_filter_bar.dart';
import '../widgets/log_line_widget.dart';
import '../widgets/log_scroll_bar.dart';

/// 日志查看页 — 搜索跳转 + 滚动条导航
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
  final Set<int> _expandedIndices = {};
  bool _isSearching = false;
  String _searchQuery = '';
  List<int> _matchIndices = [];
  int _currentMatchIdx = -1;
  Set<LogLevel> _levelFilter = {};
  DateTime? _dateStart;
  DateTime? _dateEnd;
  int _activeFilterCount = 0;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _parseLogs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
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

    // 日期范围筛选
    if (_dateStart != null || _dateEnd != null) {
      filterCount++;
      entries = entries.where((e) {
        if (e.isContinuation) return true;
        if (e.dateTime == null) return _dateStart == null && _dateEnd == null;
        if (_dateStart != null && e.dateTime!.isBefore(_dateStart!)) return false;
        if (_dateEnd != null && e.dateTime!.isAfter(_dateEnd!)) return false;
        return true;
      }).toList();
    }

    setState(() {
      _filteredEntries = entries;
      _activeFilterCount = filterCount;
    });

    // 重新计算搜索匹配
    if (_searchQuery.isNotEmpty) _computeMatches();
  }

  // ─── 搜索导航 ───

  Timer? _searchDebounce;

  void _computeMatches() {
    if (_searchQuery.isEmpty) {
      _matchIndices = [];
      _currentMatchIdx = -1;
      return;
    }
    final q = _searchQuery.toLowerCase();
    final indices = <int>[];
    for (var i = 0; i < _filteredEntries.length; i++) {
      if (_filteredEntries[i].rawText.toLowerCase().contains(q)) {
        indices.add(i);
      }
    }
    _matchIndices = indices;
    _currentMatchIdx = indices.isNotEmpty ? 0 : -1;
  }

  void _jumpToCurrentMatch() {
    if (_currentMatchIdx < 0 || _matchIndices.isEmpty) return;
    final targetIndex = _matchIndices[_currentMatchIdx];
    _scrollToIndex(targetIndex);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) {
      // 重试：等下一帧布局完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(index);
      });
      return;
    }
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(index);
      });
      return;
    }

    // 校准估算：用当前可见的第一项推算平均行高
    final viewport = position.viewportDimension;
    final estimatedItemHeight = _estimateItemHeight(position);
    final targetTop = index * estimatedItemHeight;

    // 目标位置：让匹配行出现在视口 1/3 处
    final target = (targetTop - viewport * 0.3).clamp(0.0, maxScroll);

    // 取消旧动画，直接跳转
    _scrollController.jumpTo(target);
  }

  /// 根据当前可见区域估算每行平均高度
  double _estimateItemHeight(ScrollPosition position) {
    // 用总内容高度 / 总行数 作为粗略估算
    final maxScroll = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final totalContent = maxScroll + viewport;
    if (_filteredEntries.length <= 1) return 50;
    final avg = totalContent / _filteredEntries.length;
    return avg.clamp(20.0, 200.0);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchQuery = query;
    _computeMatches();

    if (_matchIndices.isNotEmpty) {
      _currentMatchIdx = 0;
      // 取消旧动画后延迟跳转，等 UI 刷新
      _searchDebounce = Timer(const Duration(milliseconds: 80), () {
        if (mounted) _jumpToCurrentMatch();
      });
    }
    setState(() {});
  }

  void _onPrevMatch() {
    if (_matchIndices.isEmpty) return;
    _currentMatchIdx =
        (_currentMatchIdx - 1 + _matchIndices.length) % _matchIndices.length;
    _jumpToCurrentMatch();
    setState(() {});
  }

  void _onNextMatch() {
    if (_matchIndices.isEmpty) return;
    _currentMatchIdx = (_currentMatchIdx + 1) % _matchIndices.length;
    _jumpToCurrentMatch();
    setState(() {});
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _matchIndices = [];
        _currentMatchIdx = -1;
      }
    });
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
  bool isCurrentMatch(int index) =>
      _searchQuery.isNotEmpty &&
      _currentMatchIdx >= 0 &&
      _matchIndices.isNotEmpty &&
      index == _matchIndices[_currentMatchIdx];

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

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
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
    final parts = <String>[base];
    if (widget.encoding != null && widget.encoding != 'utf-8') {
      parts.add('编码: ${widget.encoding}');
    }
    if (_searchQuery.isNotEmpty) {
      parts.add('匹配 ${_matchIndices.length} 处');
    }
    return parts.join('  ·  ');
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
            Text(fileName, style: const TextStyle(fontSize: 15)),
            Text(
              _buildSubtitle(sizeStr),
              style: TextStyle(fontSize: 10,
                  color: _isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
        actions: [
          if (levelCounts.isNotEmpty)
            Center(child: _buildLevelSummary(levelCounts)),
          IconButton(
            icon: Icon(_isSearching ? Icons.search_off : Icons.search,
                size: 20),
            tooltip: '搜索',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            tooltip: '分享文件',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            LogFilterBar(
              isDark: _isDark,
              onSearchChanged: _onSearchChanged,
              onPrevMatch: _onPrevMatch,
              onNextMatch: _onNextMatch,
              matchCount: _matchIndices.length,
              currentMatch: _currentMatchIdx + 1,
              onLevelFilterChanged: _onLevelFilterChanged,
              onClose: _toggleSearch,
              startDate: _dateStart,
              endDate: _dateEnd,
              onStartDateChanged: _onStartDateChanged,
              onEndDateChanged: _onEndDateChanged,
            ),
          if (hasActiveFilter)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: _isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
              child: Row(
                children: [
                  Text(
                    '筛选: ${_filteredEntries.length} / ${_allEntries.length} 条',
                    style: TextStyle(fontSize: 11,
                        color: _isDark ? Colors.white70 : Colors.black87),
                  ),
                  if (_dateRangeDesc.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.date_range, size: 11,
                        color: _isDark ? Colors.white54 : Colors.black54),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(_dateRangeDesc,
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace',
                              color: _isDark ? Colors.white54 : Colors.black54),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                _filteredEntries.isEmpty
                    ? Center(
                        child: Text(
                          _allEntries.isEmpty ? '无日志内容' : '无匹配结果',
                          style: TextStyle(
                              color: _isDark ? Colors.white38 : Colors.black38),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _filteredEntries.length,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(right: 38),
                        itemBuilder: (context, index) {
                          return LogLineWidget(
                            entry: _filteredEntries[index],
                            isDark: _isDark,
                            highlightQuery: _searchQuery,
                            isCurrentMatch: isCurrentMatch(index),
                            isExpanded: _expandedIndices.contains(index),
                            onTap: () => _toggleExpand(index),
                          );
                        },
                      ),
                if (_filteredEntries.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 36,
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
    );
  }

  Widget _buildLevelSummary(Map<LogLevel, int> counts) {
    final items = [LogLevel.error, LogLevel.warning, LogLevel.info, LogLevel.debug];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((level) {
        final count = counts[level] ?? 0;
        if (count == 0) return const SizedBox.shrink();
        final color = _isDark ? level.darkColor : level.lightColor;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
              const SizedBox(width: 1),
              Text('$count',
                  style: TextStyle(fontSize: 9, fontFamily: 'monospace',
                      color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}