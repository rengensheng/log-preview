import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 文件打开历史记录条目
class HistoryEntry {
  final String path;
  final String fileName;
  final int fileSize;
  final DateTime openedAt;

  const HistoryEntry({
    required this.path,
    required this.fileName,
    required this.fileSize,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
        'fileSize': fileSize,
        'openedAt': openedAt.millisecondsSinceEpoch,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        path: json['path'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        openedAt:
            DateTime.fromMillisecondsSinceEpoch(json['openedAt'] as int),
      );
}

/// 文件打开历史管理 — 持久化最近打开的文件列表
class HistoryService {
  static const _maxEntries = 20;
  static const _fileName = 'log_viewer_history.json';

  List<HistoryEntry> _entries = [];
  bool _loaded = false;

  /// 获取历史文件路径
  Future<File> get _historyFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 加载历史记录
  Future<List<HistoryEntry>> loadHistory() async {
    if (_loaded) return List.unmodifiable(_entries);
    try {
      final file = await _historyFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = json.decode(content) as List<dynamic>;
        _entries = list
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        // 按时间倒序排列
        _entries.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      }
    } catch (_) {
      _entries = [];
    }
    _loaded = true;
    return List.unmodifiable(_entries);
  }

  /// 添加一条历史记录（去重、裁剪）
  Future<void> addHistory({
    required String path,
    required String fileName,
    required int fileSize,
  }) async {
    await loadHistory();
    // 移除已存在的同路径记录
    _entries.removeWhere((e) => e.path == path);
    // 插入到最前面
    _entries.insert(
      0,
      HistoryEntry(
        path: path,
        fileName: fileName,
        fileSize: fileSize,
        openedAt: DateTime.now(),
      ),
    );
    // 截断
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    await _save();
  }

  /// 删除一条历史记录
  Future<void> removeHistory(String path) async {
    await loadHistory();
    _entries.removeWhere((e) => e.path == path);
    await _save();
  }

  /// 清空全部历史
  Future<void> clearAll() async {
    _entries.clear();
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _historyFile;
      await file.writeAsString(
        json.encode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
