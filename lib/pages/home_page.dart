import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../services/file_service.dart';
import '../services/history_service.dart';
import 'log_viewer_page.dart';

/// Android 原生通信通道
const _channel = MethodChannel('com.example.log_preview/intent');

/// 首页 — 欢迎界面 + 文件选择入口 + 历史记录
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _fileService = FileService();
  final _historyService = HistoryService();
  List<HistoryEntry> _history = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _checkInitialIntent();
    _loadHistory();
  }
  Future<void> _loadHistory() async {
    final list = await _historyService.loadHistory();
    if (mounted) setState(() => _history = list);
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFile' && call.arguments is String) {
        final path = call.arguments as String;
        if (mounted) _openFile(path);
      }
    });
  }

  Future<void> _checkInitialIntent() async {
    try {
      final path = await _channel.invokeMethod<String>('getInitialFile');
      if (path != null && path.isNotEmpty && mounted) {
        _openFile(path);
      }
    } on MissingPluginException {
      // 非 Android 平台忽略
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['log', 'txt'],
        allowMultiple: false,
      );
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        _openFile(result.files.first.path!);
      }
    } catch (e) {
      _showError('选择文件失败: $e');
    }
  }

  Future<void> _openFile(String path) async {
    setState(() { _isLoading = true; _error = null; });

    final result = await _fileService.readLines(path);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // 存入历史
      await _historyService.addHistory(
        path: result.filePath!,
        fileName: _fileService.fileNameFromPath(result.filePath!),
        fileSize: result.fileSize!,
      );
      await _loadHistory();

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LogViewerPage(
            lines: result.lines!,
            filePath: result.filePath!,
            fileSize: result.fileSize!,
            encoding: result.encoding,
          ),
        ),
      );
    } else {
      _showError(result.error ?? '未知错误');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _removeHistory(String path) async {
    await _historyService.removeHistory(path);
    await _loadHistory();
  }

  Future<void> _clearAllHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空全部打开历史吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _historyService.clearAll();
      await _loadHistory();
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);
    final hasHistory = _history.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: hasHistory
            ? _buildWithHistory(isDark)
            : _buildEmptyState(isDark),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal_rounded, size: 72,
                color: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF1565C0)),
            const SizedBox(height: 20),
            Text('日志查看器',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('支持 .log / .txt 格式\n支持从其他应用"打开方式"启动',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 32),
            _buildOpenButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWithHistory(bool isDark) {
    return CustomScrollView(
      slivers: [
        // 头部
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal_rounded, size: 28,
                        color: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF1565C0)),
                    const SizedBox(width: 10),
                    Text('日志查看器',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildOpenButton(isDark),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        // 历史记录标题
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
            child: Row(
              children: [
                Icon(Icons.history, size: 16,
                    color: isDark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 6),
                Text('最近打开',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54)),
                const Spacer(),
                if (_history.length > 3)
                  GestureDetector(
                    onTap: _clearAllHistory,
                    child: Text('清空',
                        style: TextStyle(fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38)),
                  ),
              ],
            ),
          ),
        ),
        // 历史列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = _history[index];
              return _buildHistoryItem(entry, isDark);
            },
            childCount: _history.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildOpenButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _pickFile,
        icon: _isLoading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.folder_open, size: 20),
        label: Text(_isLoading ? '加载中...' : '选择日志文件'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF0D47A1) : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(HistoryEntry entry, bool isDark) {
    final sizeStr = _fileService.formatFileSize(entry.fileSize);
    final timeStr = _formatTime(entry.openedAt);

    return Dismissible(
      key: Key(entry.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withAlpha(80),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _removeHistory(entry.path),
      child: InkWell(
        onTap: () => _openFile(entry.path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // 文件图标
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white10 : Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined, size: 20,
                    color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 12),
              // 文件信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.fileName,
                        style: TextStyle(fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(sizeStr,
                            style: TextStyle(fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38)),
                        const SizedBox(width: 8),
                        Text(timeStr,
                            style: TextStyle(fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                    // 路径
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(entry.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10,
                              color: isDark ? Colors.white24 : Colors.black26)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18,
                  color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}