#!/usr/bin/env python3
"""
日志查看器 App 图标生成器
生成 Android 所有密度级别的启动图标 + 自适应图标
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

# ─── 输出目录 ───
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIPMAP_DIRS = {
    "mdpi": os.path.join(PROJECT_ROOT, "android/app/src/main/res/mipmap-mdpi"),
    "hdpi": os.path.join(PROJECT_ROOT, "android/app/src/main/res/mipmap-hdpi"),
    "xhdpi": os.path.join(PROJECT_ROOT, "android/app/src/main/res/mipmap-xhdpi"),
    "xxhdpi": os.path.join(PROJECT_ROOT, "android/app/src/main/res/mipmap-xxhdpi"),
    "xxxhdpi": os.path.join(PROJECT_ROOT, "android/app/src/main/res/mipmap-xxxhdpi"),
}
PLAYSTORE_DIR = os.path.join(PROJECT_ROOT, "android/app/src/main/")

# 各密度对应的基础尺寸（不含 adaptive icon 额外尺寸）
LAUNCHER_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
PLAYSTORE_SIZE = 512

# ─── 配色方案 ───
BG_COLOR = (30, 30, 40)          # 深色背景
BG_GRADIENT_TOP = (40, 45, 60)   # 渐变顶部
CARD_BG = (35, 38, 50)           # 文档卡片背景
LINE_COLORS = [
    (239, 83, 80),    # 红色 — Error
    (255, 183, 77),   # 橙色 — Warning
    (79, 195, 247),   # 蓝色 — Info
    (158, 158, 158),  # 灰色 — Debug
    (79, 195, 247),   # 蓝色
    (158, 158, 158),  # 灰色
]
ACCENT = (79, 195, 247)          # 主题蓝色
CARD_BORDER = (60, 65, 80)


def create_output_dirs():
    """创建所有输出目录"""
    for d in list(MIPMAP_DIRS.values()) + [PLAYSTORE_DIR]:
        os.makedirs(d, exist_ok=True)


def draw_icon(size: int, for_adaptive_fg: bool = False) -> Image.Image:
    """
    绘制图标核心图形
    - size: 画布尺寸（正方形）
    - for_adaptive_fg: 是否用于自适应图标前景（此时背景透明）
    返回 RGBA Image
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = size * 0.12
    corner_radius = size * 0.18

    if not for_adaptive_fg:
        # ─── 背景：圆角矩形 + 渐变 ───
        _draw_rounded_rect(draw, (0, 0, size, size), corner_radius, BG_COLOR)
        # 顶部微光
        overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        for y in range(int(size * 0.6)):
            alpha = int(25 * (1 - y / (size * 0.6)))
            overlay_draw.rectangle([0, y, size, y + 1], fill=(255, 255, 255, alpha))
        img = Image.alpha_composite(img, overlay)

    # ─── 文档卡片 ───
    card_left = margin
    card_top = margin * 1.6
    card_right = size - margin
    card_bottom = size - margin * 0.8
    _draw_rounded_rect(
        draw,
        (card_left, card_top, card_right, card_bottom),
        corner_radius * 0.6,
        CARD_BG,
    )
    # 卡片边框
    _draw_rounded_rect_outline(
        draw,
        (card_left, card_top, card_right, card_bottom),
        corner_radius * 0.6,
        CARD_BORDER,
        width=max(1, int(size * 0.008)),
    )

    # ─── 代码行（彩色横条） ───
    line_area_left = card_left + size * 0.09
    line_area_right = card_right - size * 0.09
    line_area_width = line_area_right - line_area_left
    line_start_y = card_top + size * 0.1
    line_gap = size * 0.065
    line_height = size * 0.028
    num_lines = 8

    for i in range(num_lines):
        y = line_start_y + i * (line_height + line_gap)
        color = LINE_COLORS[i % len(LINE_COLORS)]
        line_w = line_area_width * (0.5 + 0.5 * ((i * 0.7 + 3) % 1.0))

        # 左侧彩色圆点（日志级别标记）
        dot_radius = line_height * 1.2
        dot_x = line_area_left + dot_radius
        dot_y = y + line_height / 2
        draw.ellipse(
            [
                dot_x - dot_radius,
                dot_y - dot_radius,
                dot_x + dot_radius,
                dot_y + dot_radius,
            ],
            fill=color,
        )

        # 横线
        bar_left = dot_x + dot_radius + size * 0.02
        bar_right = bar_left + line_w - dot_radius * 2 - size * 0.02
        _draw_rounded_rect(
            draw,
            (bar_left, y, bar_right, y + line_height),
            line_height / 2,
            color + (180,),  # 半透明
        )

    # ─── 放大镜图标（右上角） ───
    glass_cx = card_right - size * 0.1
    glass_cy = card_top + size * 0.065
    glass_r = size * 0.045
    glass_stroke = max(1, int(size * 0.012))

    # 镜圈
    draw.ellipse(
        [
            glass_cx - glass_r,
            glass_cy - glass_r,
            glass_cx + glass_r,
            glass_cy + glass_r,
        ],
        outline=ACCENT + (200,),
        width=glass_stroke,
    )
    # 手柄
    handle_len = glass_r * 0.8
    angle = math.radians(45)
    hx = glass_cx + glass_r * 0.7
    hy = glass_cy + glass_r * 0.7
    hx2 = hx + handle_len * math.cos(angle)
    hy2 = hy + handle_len * math.sin(angle)
    draw.line([hx, hy, hx2, hy2], fill=ACCENT + (200,), width=glass_stroke)

    return img


def draw_adaptive_bg(size: int) -> Image.Image:
    """自适应图标纯色背景层"""
    img = Image.new("RGBA", (size, size), BG_COLOR)
    return img


def _draw_rounded_rect(draw, bbox, radius, fill):
    """绘制圆角矩形"""
    x1, y1, x2, y2 = bbox
    r = min(radius, (x2 - x1) / 2, (y2 - y1) / 2)
    draw.rounded_rectangle([x1, y1, x2, y2], radius=r, fill=fill)


def _draw_rounded_rect_outline(draw, bbox, radius, outline, width=1):
    """绘制圆角矩形边框"""
    x1, y1, x2, y2 = bbox
    r = min(radius, (x2 - x1) / 2, (y2 - y1) / 2)
    draw.rounded_rectangle([x1, y1, x2, y2], radius=r, outline=outline, width=width)


def generate_all():
    """生成所有尺寸的图标"""
    create_output_dirs()

    # ─── 标准启动图标 ic_launcher ───
    for density, size in LAUNCHER_SIZES.items():
        path = os.path.join(MIPMAP_DIRS[density], "ic_launcher.png")
        img = draw_icon(size, for_adaptive_fg=False)
        img.save(path, "PNG")
        print(f"  ✅ {density:7s}  {size}x{size}  →  {path}")

    # ─── Play Store 图标 ───
    ps_path = os.path.join(PLAYSTORE_DIR, "ic_launcher_playstore.png")
    img = draw_icon(PLAYSTORE_SIZE, for_adaptive_fg=False)
    img.save(ps_path, "PNG")
    print(f"  ✅ playstore  {PLAYSTORE_SIZE}x{PLAYSTORE_SIZE}  →  {ps_path}")

    # ─── 自适应图标 (Android 8+) ───
    # 前景层（需要在安全区内绘制，留出 33% 边距）
    for density in LAUNCHER_SIZES:
        size = LAUNCHER_SIZES[density] * 2  # 自适应图标用 dp * 2 的尺寸
        if size < 108:
            size = 108
        fg_path = os.path.join(MIPMAP_DIRS[density], "ic_launcher_foreground.png")
        bg_path = os.path.join(MIPMAP_DIRS[density], "ic_launcher_background.png")

        # 前景：在 108dp 安全区内绘制
        fg_img = draw_icon(size, for_adaptive_fg=True)
        fg_img.save(fg_path, "PNG")

        # 背景：纯色
        bg_img = draw_adaptive_bg(size)
        bg_img.save(bg_path, "PNG")
        print(f"  ✅ {density:7s}  adaptive fg/bg {size}x{size}")

    print("\n🎉 所有图标生成完毕！")


if __name__ == "__main__":
    print("🖼️  日志查看器 App 图标生成器")
    print("=" * 50)
    generate_all()
