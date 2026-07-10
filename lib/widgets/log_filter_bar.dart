import 'package:flutter/material.dart';

import '../core/log_level.dart';

/// 日志筛选栏 — 文本搜索 + 级别筛选 + 日期范围
class LogFilterBar extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<LogLevel>> onLevelFilterChanged;
  final VoidCallback? onClose;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?>? onStartDateChanged;
  final ValueChanged<DateTime?>? onEndDateChanged;

  const LogFilterBar({
    super.key,
    required this.isDark,
    required this.onSearchChanged,
    required this.onLevelFilterChanged,
    this.onClose,
    this.startDate,
    this.endDate,
    this.onStartDateChanged,
    this.onEndDateChanged,
  });

  @override
  State<LogFilterBar> createState() => _LogFilterBarState();
}

class _LogFilterBarState extends State<LogFilterBar> {
  final _searchController = TextEditingController();
  final _selectedLevels = <LogLevel>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (widget.startDate ?? DateTime.now().subtract(const Duration(days: 1)))
        : (widget.endDate ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(primary: Colors.blue)
                : const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    // 选择具体时间
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(primary: Colors.blue)
                : const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (isStart) {
      widget.onStartDateChanged?.call(dt);
    } else {
      widget.onEndDateChanged?.call(dt);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '不限';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF252526) : const Color(0xFFF5F5F5);
    final chipBg = widget.isDark ? Colors.white12 : Colors.black12;
    final accent = widget.isDark ? Colors.blue.shade300 : Colors.blue;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          Row(
            children: [
              Icon(Icons.search,
                  size: 20,
                  color: widget.isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索日志内容...',
                    hintStyle: TextStyle(
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    widget.onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (widget.onClose != null)
                IconButton(
                  icon: Icon(Icons.close,
                      color: widget.isDark ? Colors.white54 : Colors.black54),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 级别筛选芯片
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LogLevel.values
                  .where((l) => l != LogLevel.unknown)
                  .map((level) {
                final selected = _selectedLevels.contains(level);
                final color =
                    widget.isDark ? level.darkColor : level.lightColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(level.label,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace')),
                    selected: selected,
                    selectedColor: color.withAlpha(60),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: selected
                          ? color
                          : (widget.isDark ? Colors.white54 : Colors.black54),
                      fontSize: 11,
                    ),
                    side: BorderSide(color: color.withAlpha(80)),
                    backgroundColor: chipBg,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedLevels.add(level);
                        } else {
                          _selectedLevels.remove(level);
                        }
                      });
                      widget.onLevelFilterChanged(_selectedLevels);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 日期范围行
          Row(
            children: [
              Icon(Icons.date_range,
                  size: 16,
                  color: widget.isDark ? Colors.white38 : Colors.black38),
              const SizedBox(width: 6),
              // 开始日期
              _DateChip(
                label: '开始: ${_formatDateTime(widget.startDate)}',
                isDark: widget.isDark,
                accent: accent,
                isActive: widget.startDate != null,
                onTap: () => _pickDate(isStart: true),
                onClear: widget.startDate != null
                    ? () => widget.onStartDateChanged?.call(null)
                    : null,
              ),
              const SizedBox(width: 4),
              Text('—',
                  style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(width: 4),
              // 结束日期
              _DateChip(
                label: '结束: ${_formatDateTime(widget.endDate)}',
                isDark: widget.isDark,
                accent: accent,
                isActive: widget.endDate != null,
                onTap: () => _pickDate(isStart: false),
                onClear: widget.endDate != null
                    ? () => widget.onEndDateChanged?.call(null)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 日期选择小芯片
class _DateChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color accent;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({
    required this.label,
    required this.isDark,
    required this.accent,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withAlpha(30)
              : (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? accent.withAlpha(100)
                : (isDark ? Colors.white24 : Colors.black26),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isActive
                    ? accent
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
