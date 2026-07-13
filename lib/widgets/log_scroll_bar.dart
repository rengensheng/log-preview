import 'package:flutter/material.dart';

/// 大滑块滚动条 — 醒目、可拖拽、始终可见
class LogScrollBar extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final bool isDark;

  const LogScrollBar({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.isDark,
  });

  @override
  State<LogScrollBar> createState() => _LogScrollBarState();
}

class _LogScrollBarState extends State<LogScrollBar> {
  bool _isDragging = false;
  double _dragFraction = 0;
  double _displayFraction = 0;

  static const _totalWidth = 36.0;
  static const _barWidth = 8.0;
  static const _minThumbHeight = 36.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScrollUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScrollUpdate);
    super.dispose();
  }

  void _onScrollUpdate() {
    if (_isDragging || !mounted) return;
    final f = _scrollFraction;
    if ((f - _displayFraction).abs() > 0.001) {
      setState(() => _displayFraction = f);
    }
  }

  double get _scrollFraction {
    final p = widget.controller.hasClients ? widget.controller.position : null;
    if (p == null || p.maxScrollExtent <= 0) return 0;
    return (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
  }

  double _thumbFraction(double barHeight) {
    final p = widget.controller.hasClients ? widget.controller.position : null;
    if (p == null) return 0.3;
    final vp = p.viewportDimension;
    final ms = p.maxScrollExtent;
    if (ms <= 0) return 1.0;
    return (vp / (ms + vp)).clamp(0.05, 1.0);
  }

  void _onDragStart(DragStartDetails d) {
    _isDragging = true;
    _updateDrag(d.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _updateDrag(d.localPosition);
  }

  void _onDragEnd(DragEndDetails d) {
    _isDragging = false;
    _displayFraction = _dragFraction;
    final p = widget.controller.hasClients ? widget.controller.position : null;
    if (p != null) {
      widget.controller.jumpTo(
        (_dragFraction * p.maxScrollExtent).clamp(0.0, p.maxScrollExtent),
      );
    }
    if (mounted) setState(() {});
  }

  void _updateDrag(Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final h = box.size.height;
    final th = _thumbFraction(h).clamp(_minThumbHeight, h);
    final trackLen = h - th;
    final center = localPos.dy.clamp(th / 2, h - th / 2);
    _dragFraction = ((center - th / 2) / trackLen).clamp(0.0, 1.0);

    final p = widget.controller.hasClients ? widget.controller.position : null;
    if (p != null) {
      widget.controller.jumpTo(
        (_dragFraction * p.maxScrollExtent).clamp(0.0, p.maxScrollExtent),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.isDark;

    // 滑块颜色 — 静止时半透明，拖拽时实色
    final thumbColor = d
        ? const Color(0x55FFFFFF)
        : const Color(0x55000000);
    final thumbDragColor = d
        ? const Color(0xFF90CAF9)
        : const Color(0xFF1976D2);

    return SizedBox(
      width: _totalWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barHeight = constraints.maxHeight;
          if (barHeight <= 0) return const SizedBox.shrink();

          final thumbH =
              (_thumbFraction(barHeight) * barHeight).clamp(_minThumbHeight, barHeight);
          final trackLen = barHeight - thumbH;
          final fraction = _isDragging ? _dragFraction : _displayFraction;
          final thumbTop = trackLen * fraction;
          final pct = '${(fraction * 100).toStringAsFixed(0)}%';
          final idx = (fraction * (widget.itemCount - 1)).round();
          final label = _isDragging ? '#$idx $pct' : pct;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 触摸手势层
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                ),
              ),
              // 方形滑块（无轨道背景）
              Positioned(
                right: (_totalWidth - _barWidth) / 2,
                top: thumbTop,
                child: Container(
                  width: _barWidth,
                  height: thumbH,
                  decoration: BoxDecoration(
                    color: _isDragging ? thumbDragColor : thumbColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 百分比标签
              Positioned(
                left: 0,
                top: (thumbTop + thumbH / 2 - 10).clamp(0.0, barHeight - 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: (d ? Colors.grey.shade800 : Colors.grey.shade200)
                        .withAlpha(220),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight:
                          _isDragging ? FontWeight.bold : FontWeight.normal,
                      color: d ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}