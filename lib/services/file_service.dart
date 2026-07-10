import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 文件读取服务 — 多编码兼容，自动回退
class FileService {
  /// 读取文件全部文本行，自动检测编码
  Future<ReadResult> readLines(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return ReadResult.error('文件不存在: $path');
      }
      final size = await file.length();
      var bytes = await file.readAsBytes();

      // 空文件
      if (bytes.isEmpty) {
        return ReadResult.success([], path, size, 0, encoding: 'utf-8');
      }

      // 检测并剥离 BOM
      final bomEncoding = _detectBom(bytes);
      if (bomEncoding != null) {
        // 如果是带 BOM 的 UTF-8，跳过 BOM 头后用 UTF-8 解码
        if (bomEncoding == 'utf-8-bom') {
          bytes = bytes.sublist(3);
          final content = utf8.decode(bytes);
          final lines = const LineSplitter().convert(content);
          return ReadResult.success(lines, path, size, content.length,
              encoding: 'utf-8');
        }
        // UTF-16 BOM 的情况，尝试用 latin1 兜底（UTF-16 在 Dart 中需要额外处理）
      }

      // 尝试编码链
      final decoders = _buildDecoderChain();
      for (final decoder in decoders) {
        try {
          final content = decoder.convert(bytes);
          final lines = const LineSplitter().convert(content);
          return ReadResult.success(lines, path, size, content.length,
              encoding: decoder.label);
        } on FormatException {
          continue;
        }
      }

      return ReadResult.error('无法解码文件内容');
    } on FileSystemException catch (e) {
      return ReadResult.error('读取文件失败: ${e.message}');
    } on Exception catch (e) {
      return ReadResult.error('读取异常: $e');
    }
  }

  /// 构建编码尝试链
  List<_LabeledDecoder> _buildDecoderChain() {
    return [
      _LabeledDecoder('utf-8', utf8.decoder),
      _LabeledDecoder('utf-8 (宽松)', _Utf8AllowMalformedDecoder()),
      _LabeledDecoder('latin1', latin1.decoder),
    ];
  }

  /// BOM 检测，返回编码标识或 null
  String? _detectBom(List<int> bytes) {
    if (bytes.length < 2) return null;
    // UTF-8 BOM: EF BB BF
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return 'utf-8-bom';
    }
    // UTF-16 LE BOM: FF FE
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) return 'utf-16le';
    // UTF-16 BE BOM: FE FF
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) return 'utf-16be';
    return null;
  }

  /// 获取文件名
  String fileNameFromPath(String path) {
    final segments = path.split(Platform.pathSeparator);
    return segments.lastWhere((s) => s.isNotEmpty, orElse: () => 'unknown');
  }

  /// 文件大小描述
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 带标签的字符串解码器
class _LabeledDecoder {
  final String label;
  final Converter<List<int>, String> converter;

  const _LabeledDecoder(this.label, this.converter);

  String convert(List<int> bytes) => converter.convert(bytes);
}

/// 宽松 UTF-8 解码器：非法字节序列用 � 替代
class _Utf8AllowMalformedDecoder extends Converter<List<int>, String> {
  @override
  String convert(List<int> input) {
    return utf8.decode(input, allowMalformed: true);
  }
}

/// 文件读取结果
@immutable
class ReadResult {
  final List<String>? lines;
  final String? filePath;
  final int? fileSize;
  final int? charCount;
  final String? error;
  final bool isSuccess;
  final String? encoding;

  const ReadResult._({
    this.lines,
    this.filePath,
    this.fileSize,
    this.charCount,
    this.error,
    this.encoding,
    required this.isSuccess,
  });

  factory ReadResult.success(
    List<String> lines,
    String path,
    int size,
    int chars, {
    String? encoding,
  }) {
    return ReadResult._(
      lines: lines,
      filePath: path,
      fileSize: size,
      charCount: chars,
      encoding: encoding,
      isSuccess: true,
    );
  }

  factory ReadResult.error(String message) {
    return ReadResult._(error: message, isSuccess: false);
  }
}
