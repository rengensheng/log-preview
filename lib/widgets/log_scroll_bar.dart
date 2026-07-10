import 'package:flutter/material.dart';

/// 可拖拽的快速滚动条 — 始终可见的进度指示器
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
  String _tooltipText = '';
  double _displayFraction = 0;

  static const _barWidth = 8.0;
  static const _hitWidth = 28.0;
  static const _minThumbHeight = 28.0;

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
    final position =
        widget.controller.hasClients ? widget.controller.position : null;
    if (position == null || position.maxScrollExtent <= 0) return 0;
    return (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
  }

  double get _thumbFraction {
    final position =
        widget.controller.hasClients ? widget.controller.position : null;
    if (position == null) return 0.3;
    final viewport = position.viewportDimension;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return 1.0;
    return (viewport / (maxScroll + viewport)).clamp(0.05, 1.0);
  }

  int _fractionToIndex(double fraction) {
    if (widget.itemCount <= 1) return 0;
    return (fraction * (widget.itemCount - 1))
        .round()
        .clamp(0, widget.itemCount - 1);
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _updateDrag(details.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateDrag(details.localPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    _displayFraction = _dragFraction;
    final position =
        widget.controller.hasClients ? widget.controller.position : null;
    if (position != null) {
      widget.controller.jumpTo(
        (_dragFraction * position.maxScrollExtent)
            .clamp(0.0, position.maxScrollExtent),
      );
    }
    if (mounted) setState(() {});
  }

  void _updateDrag(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final barHeight = box.size.height;
    final thumbHeight =
        (_thumbFraction * barHeight).clamp(_minThumbHeight, barHeight);
    final trackLength = barHeight - thumbHeight;
    final thumbCenter = localPosition.dy
        .clamp(thumbHeight / 2, barHeight - thumbHeight / 2);
    _dragFraction =
        ((thumbCenter - thumbHeight / 2) / trackLength).clamp(0.0, 1.0);

    final idx = _fractionToIndex(_dragFraction);
    final pct = (_dragFraction * 100).toStringAsFixed(1);
    _tooltipText = '#$idx  $pct%';

    final position =
        widget.controller.hasClients ? widget.controller.position : null;
    if (position != null) {
      widget.controller.jumpTo(
        (_dragFraction * position.maxScrollExtent)
            .clamp(0.0, position.maxScrollExtent),
      );
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = constraints.maxHeight;
        final thumbHeight =
            (_thumbFraction * barHeight).clamp(_minThumbHeight, barHeight);
        final trackLength = barHeight - thumbHeight;
        final fraction = _isDragging ? _dragFraction : _displayFraction;
        final thumbTop = trackLength * fraction;

        // 更醒目的颜色
        final thumbColor =
            widget.isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600;
        final thumbDragColor =
            widget.isDark ? Colors.blue.shade300 : Colors.blue;
        final trackColor =
            widget.isDark ? Colors.white24 : Colors.black26;

        final pctStr = '${(fraction * 100).toStringAsFixed(0)}%';

        return Stack(
          children: [
            // 触摸区域
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Container(
                  width: _hitWidth,
                  color: Colors.transparent,
                ),
              ),
            ),
            // 轨道（更明显）
            Positioned(
              right: (_hitWidth - _barWidth) / 2,
              top: 0,
              bottom: 0,
              child: Container(
                width: _barWidth,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(_barWidth / 2),
                ),
              ),
            ),
            // 滑块（更宽更亮）
            Positioned(
              right:
                  (_hitWidth - _barWidth) / 2 - (_isDragging ? 1 : 0),
              top: thumbTop,
              child: Container(
                width: _barWidth + (_isDragging ? 2 : 0),
                height: thumbHeight,
                decoration: BoxDecoration(
                  color: _isDragging ? thumbDragColor : thumbColor,
                  borderRadius: BorderRadius.circular(_barWidth / 2 + 1),
                  boxShadow: [
                    BoxShadow(
                      color: (_isDragging ? thumbDragColor : thumbColor)
                          .withAlpha(60),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            // 百分比标签（始终显示在滑块左侧）
            Positioned(
              right: _hitWidth,
              top: (thumbTop + thumbHeight / 2 - 10)
                  .clamp(0.0, barHeight - 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200)
                      .withAlpha(200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isDragging ? _tooltipText : pctStr,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight:
                        _isDragging ? FontWeight.bold : FontWeight.normal,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}