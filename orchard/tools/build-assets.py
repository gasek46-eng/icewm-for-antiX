#!/usr/bin/env python3
"""
build-assets.py — генерирует графику темы Orchard.

Создаёт:
  icewm/Orchard{,-Dark}/   — кнопки-«светофор» (XPM двойной высоты) и значок меню
  wallpapers/              — обои (светлые и тёмные), нарисованные с нуля
  icons/                   — значки «Настройки Orchard» и логотипа

Нужны: Python 3, Pillow; ImageMagick (convert/magick) — для сохранения XPM.
Запуск из папки orchard:   python3 tools/build-assets.py
Готовые файлы уже лежат в репозитории — запускать нужно, только если меняете дизайн.
"""
import math
import os
import random
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 8  # сглаживание: рисуем в 8 раз крупнее и уменьшаем

IM = shutil.which("magick") or shutil.which("convert")
if not IM:
    sys.exit("Нужен ImageMagick (magick или convert)")


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, f):
    """f<1 — темнее, f>1 — светлее"""
    if f < 1:
        return tuple(int(c * f) for c in rgb)
    return tuple(int(c + (255 - c) * (f - 1)) for c in rgb)


def save_xpm(img, path):
    png = path[:-4] + ".tmp.png"
    img.convert("RGB").save(png)
    subprocess.run([IM, png, path], check=True)
    os.remove(png)
    # имя массива внутри XPM — по имени файла (IceWM это не важно, но аккуратнее)
    name = os.path.basename(path)[:-4].replace("-", "_")
    with open(path) as f:
        data = f.read()
    import re
    data = re.sub(r"static char \*[^\[]+\[\]", "static char *%s[]" % name, data, count=1)
    with open(path, "w") as f:
        f.write(data)


# ----------------------------------------------------------------------------
# Палитры
# ----------------------------------------------------------------------------
THEMES = {
    "Orchard": dict(
        title_active="#E9E9EB", title_inactive="#F6F6F7",
        text_active="#3A3A3C", text_inactive="#A9A9AD",
        border_active="#C6C6CA", border_inactive="#DADADE",
        bar="#F3F3F5", bar_text="#1D1D1F", bar_hover="#DCDCE0",
        menu="#F6F6F8", menu_text="#1D1D1F", menu_sep="#DCDCE0",
        accent="#007AFF", accent_text="#FFFFFF", disabled="#B0B0B5",
        dialog="#F2F2F4", input="#FFFFFF", input_text="#1D1D1F",
        gray_fill="#D5D5D8", gray_edge="#C2C2C6",
        leaf="#1D1D1F",
    ),
    "Orchard-Dark": dict(
        title_active="#3A3A3D", title_inactive="#2B2B2E",
        text_active="#E6E6E8", text_inactive="#8C8C91",
        border_active="#121214", border_inactive="#1C1C1E",
        bar="#252528", bar_text="#F2F2F4", bar_hover="#3C3C40",
        menu="#2C2C2F", menu_text="#ECECEE", menu_sep="#3E3E42",
        accent="#0A84FF", accent_text="#FFFFFF", disabled="#6E6E73",
        dialog="#2A2A2D", input="#1E1E20", input_text="#ECECEE",
        gray_fill="#4C4C50", gray_edge="#404044",
        leaf="#F2F2F4",
    ),
}

LIGHTS = {  # заливка, обводка, цвет значка при наведении
    "close": ("#FF5F57", "#E2463F", "#4D0000"),
    "minimize": ("#FEBC2E", "#E1A116", "#985712"),
    "maximize": ("#28C840", "#14AE2A", "#0B650D"),
}
LIGHTS["restore"] = LIGHTS["maximize"]

BTN_W, TITLE_H, R = 20, 28, 6.25   # ширина кнопки, высота заголовка, радиус кружка


def draw_glyph(d, kind, cx, cy, color):
    w = 1.35 * SS
    s = 2.6 * SS
    col = color + (210,)
    if kind == "close":
        d.line([(cx - s, cy - s), (cx + s, cy + s)], fill=col, width=int(w))
        d.line([(cx - s, cy + s), (cx + s, cy - s)], fill=col, width=int(w))
    elif kind == "minimize":
        d.line([(cx - s - 0.6 * SS, cy), (cx + s + 0.6 * SS, cy)], fill=col, width=int(w))
    elif kind == "maximize":
        # две стрелки-треугольника, как у полноэкранной кнопки macOS
        a, b = 2.9 * SS, 0.7 * SS
        d.polygon([(cx - a, cy - a), (cx + b, cy - a), (cx - a, cy + b)], fill=col)
        d.polygon([(cx + a, cy + a), (cx - b, cy + a), (cx + a, cy - b)], fill=col)
    elif kind == "restore":
        a = 2.8 * SS
        d.polygon([(cx - 0.5 * SS, cy - 0.5 * SS), (cx - 0.5 * SS, cy - a), (cx - a, cy - 0.5 * SS)], fill=col)
        d.polygon([(cx + 0.5 * SS, cy + 0.5 * SS), (cx + 0.5 * SS, cy + a), (cx + a, cy + 0.5 * SS)], fill=col)


def button_frame(bg, fill, edge, glyph=None, kind=None):
    """Одна половина картинки кнопки: BTN_W x TITLE_H"""
    W, H = BTN_W * SS, TITLE_H * SS
    img = Image.new("RGBA", (W, H), hexrgb(bg) + (255,))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, r = W / 2, H / 2, R * SS
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=edge + (255,))
    r2 = r - 0.75 * SS
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=fill + (255,))
    if glyph is not None:
        draw_glyph(d, kind, cx, cy, glyph)
    img = Image.alpha_composite(img, layer)
    return img.resize((BTN_W, TITLE_H), Image.LANCZOS)


def stack(top, bottom):
    out = Image.new("RGB", (BTN_W, TITLE_H * 2))
    out.paste(top, (0, 0))
    out.paste(bottom, (0, TITLE_H))
    return out


def build_icewm_buttons(name, p, outdir):
    for kind, (fill, edge, glyph) in LIGHTS.items():
        fill, edge, glyph = hexrgb(fill), hexrgb(edge), hexrgb(glyph)
        ba = p["title_active"]
        bi = p["title_inactive"]
        pressed = shade(fill, 0.82)
        # A — активное окно: сверху обычная, снизу нажатая (со значком)
        a = stack(button_frame(ba, fill, edge),
                  button_frame(ba, pressed, shade(edge, 0.85), glyph, kind))
        # O — под мышью: со значком; нажатая — темнее
        o = stack(button_frame(ba, fill, edge, glyph, kind),
                  button_frame(ba, pressed, shade(edge, 0.85), glyph, kind))
        # I — неактивное окно: серые кружки; под мышью IceWM всё равно берёт O
        gf, ge = hexrgb(p["gray_fill"]), hexrgb(p["gray_edge"])
        i = stack(button_frame(bi, gf, ge),
                  button_frame(bi, shade(gf, 0.9), shade(ge, 0.9)))
        save_xpm(a, os.path.join(outdir, kind + "A.xpm"))
        save_xpm(o, os.path.join(outdir, kind + "O.xpm"))
        save_xpm(i, os.path.join(outdir, kind + "I.xpm"))


def leaf_image(size, color, bg):
    """Логотип Orchard — листок (оригинальный рисунок)"""
    S = size * SS
    img = Image.new("RGBA", (S, S), hexrgb(bg) + (255,) if bg else (0, 0, 0, 0))
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    col = hexrgb(color) + (255,)
    # листок: пересечение двух кругов, повёрнутое на 45°
    leaf = Image.new("L", (S, S), 0)
    m1 = Image.new("L", (S, S), 0)
    m2 = Image.new("L", (S, S), 0)
    r = S * 0.50
    c = S / 2
    off = S * 0.26
    ImageDraw.Draw(m1).ellipse([c - off - r, c - r, c - off + r, c + r], fill=255)
    ImageDraw.Draw(m2).ellipse([c + off - r, c - r, c + off + r, c + r], fill=255)
    from PIL import ImageChops
    leaf = ImageChops.multiply(m1, m2)
    leaf = leaf.resize((int(S * 0.78), int(S * 0.78)), Image.LANCZOS)
    pad = Image.new("L", (S, S), 0)
    pad.paste(leaf, (int(S * 0.11), int(S * 0.11)))
    leaf = pad.rotate(-45, resample=Image.BICUBIC)
    # прожилка
    vein = Image.new("L", (S, S), 0)
    vd = ImageDraw.Draw(vein)
    vd.line([(S * 0.30, S * 0.70), (S * 0.66, S * 0.34)], fill=255, width=max(1, int(S * 0.055)))
    from PIL import ImageChops as IC
    leaf = IC.subtract(leaf, vein)
    # черенок
    d.line([(S * 0.20, S * 0.80), (S * 0.33, S * 0.67)], fill=col, width=max(1, int(S * 0.07)))
    lay.paste(Image.new("RGBA", (S, S), col), (0, 0), leaf)
    img = Image.alpha_composite(img, lay)
    return img.resize((size, size), Image.LANCZOS)


def write_theme_file(name, p, outdir):
    def rgb(h):
        h = h.lstrip("#")
        return "rgb:%s/%s/%s" % (h[0:2], h[2:4], h[4:6])
    dark = name.endswith("Dark")
    txt = f'''# {name} — оконная тема IceWM в стиле macOS ({'тёмная' if dark else 'светлая'})
# Часть набора Orchard: https://github.com/gasek46-eng/icewm-for-antix
ThemeDescription="{name}"
ThemeAuthor="Orchard for antiX"

Look=flat

# --- Заголовок окна ---
TitleBarHeight={TITLE_H}
TitleBarJustify=50
TitleBarCentered=1
TitleBarHorzOffset=0
TitleBarVertOffset=0
TitleButtonsLeft="xim"
TitleButtonsRight=""
TitleButtonsSupported="xim"
RolloverButtonsSupported=1
ShowMenuButtonIcon=0

BorderSizeX=1
BorderSizeY=1
DlgBorderSizeX=1
DlgBorderSizeY=1
CornerSizeX=14
CornerSizeY=14

ColorActiveTitleBar="{rgb(p['title_active'])}"
ColorNormalTitleBar="{rgb(p['title_inactive'])}"
ColorActiveTitleBarText="{rgb(p['text_active'])}"
ColorNormalTitleBarText="{rgb(p['text_inactive'])}"
ColorActiveTitleBarShadow=""
ColorNormalTitleBarShadow=""
ColorActiveBorder="{rgb(p['border_active'])}"
ColorNormalBorder="{rgb(p['border_inactive'])}"
TitleFontNameXft="Inter:size=10:weight=600,sans-serif:size=10:bold"

# --- Меню ---
MenuFontNameXft="Inter:size=10,sans-serif:size=10"
ColorNormalMenu="{rgb(p['menu'])}"
ColorNormalMenuItemText="{rgb(p['menu_text'])}"
ColorActiveMenuItem="{rgb(p['accent'])}"
ColorActiveMenuItemText="{rgb(p['accent_text'])}"
ColorDisabledMenuItemText="{rgb(p['disabled'])}"
ColorDisabledMenuItemShadow=""
ColorNormalMenuSeparator="{rgb(p['menu_sep'])}"
ColorActiveMenuSeparator="{rgb(p['menu_sep'])}"
MenuIconSize=16

# --- Верхняя панель (строка меню) ---
ColorDefaultTaskBar="{rgb(p['bar'])}"
ColorNormalButton="{rgb(p['bar'])}"
ColorActiveButton="{rgb(p['bar_hover'])}"
ColorNormalButtonText="{rgb(p['bar_text'])}"
ColorActiveButtonText="{rgb(p['bar_text'])}"
ColorToolButton="{rgb(p['bar'])}"
ColorToolButtonText="{rgb(p['bar_text'])}"
ColorNormalTaskBarApp="{rgb(p['bar'])}"
ColorNormalTaskBarAppText="{rgb(p['bar_text'])}"
ColorActiveTaskBarApp="{rgb(p['bar_hover'])}"
ColorActiveTaskBarAppText="{rgb(p['bar_text'])}"
ColorMinimizedTaskBarApp="{rgb(p['bar'])}"
ColorMinimizedTaskBarAppText="{rgb(p['disabled'])}"
ColorNormalWorkspaceButton="{rgb(p['bar'])}"
ColorNormalWorkspaceButtonText="{rgb(p['bar_text'])}"
ColorActiveWorkspaceButton="{rgb(p['bar_hover'])}"
ColorActiveWorkspaceButtonText="{rgb(p['bar_text'])}"
ColorClock="{rgb(p['bar'])}"
ColorClockText="{rgb(p['bar_text'])}"
ColorApm="{rgb(p['bar'])}"
ColorApmText="{rgb(p['bar_text'])}"
ColorApmBattery="{rgb(p['bar_text'])}"
ColorApmLine="{rgb(p['bar_text'])}"
ColorApmGraphBg="{rgb(p['bar'])}"
ColorKeyboardLayoutText="{rgb(p['bar_text'])}"
TaskBarClockLeds=0
NormalButtonFontNameXft="Inter:size=10,sans-serif:size=10"
ActiveButtonFontNameXft="Inter:size=10,sans-serif:size=10"
ToolButtonFontNameXft="Inter:size=10,sans-serif:size=10"
NormalTaskBarFontNameXft="Inter:size=10,sans-serif:size=10"
ActiveTaskBarFontNameXft="Inter:size=10,sans-serif:size=10"
ClockFontNameXft="Inter:size=10:weight=500,sans-serif:size=10"
ApmFontNameXft="Inter:size=10,sans-serif:size=10"
NormalWorkspaceFontNameXft="Inter:size=10,sans-serif:size=10"
ActiveWorkspaceFontNameXft="Inter:size=10:weight=600,sans-serif:size=10:bold"

# --- Переключатель окон Alt+Tab, диалоги, подсказки ---
ColorQuickSwitch="{rgb(p['menu'])}"
ColorQuickSwitchText="{rgb(p['menu_text'])}"
ColorQuickSwitchActive="{rgb(p['accent'])}"
QuickSwitchFontNameXft="Inter:size=11,sans-serif:size=11"
ColorDialog="{rgb(p['dialog'])}"
ColorToolTip="{rgb(p['menu'])}"
ColorToolTipText="{rgb(p['menu_text'])}"
ToolTipFontNameXft="Inter:size=9,sans-serif:size=9"
ColorListBox="{rgb(p['input'])}"
ColorListBoxText="{rgb(p['input_text'])}"
ColorListBoxSelection="{rgb(p['accent'])}"
ColorListBoxSelectionText="{rgb(p['accent_text'])}"
ColorScrollBar="{rgb(p['dialog'])}"
ColorScrollBarSlider="{rgb(p['disabled'])}"
ColorScrollBarButton="{rgb(p['dialog'])}"
ColorInput="{rgb(p['input'])}"
ColorInputText="{rgb(p['input_text'])}"
ColorInputSelection="{rgb(p['accent'])}"
ColorInputSelectionText="{rgb(p['accent_text'])}"
ColorMoveSizeStatus="{rgb(p['menu'])}"
ColorMoveSizeStatusText="{rgb(p['menu_text'])}"
StatusFontNameXft="Inter:size=10,sans-serif:size=10"
'''
    with open(os.path.join(outdir, "default.theme"), "w") as f:
        f.write(txt)


# ----------------------------------------------------------------------------
# Обои
# ----------------------------------------------------------------------------
def wallpaper(path, dark, W=1920, H=1080, seed=7):
    """Мягкие волны-ленты поверх градиента. Рисуем в половинном размере и
    увеличиваем: так быстрее, а после размытия разницы не видно."""
    w, h = W // 2, H // 2
    rnd = random.Random(seed)
    if dark:
        top, bottom = hexrgb("#141A3A"), hexrgb("#2B1840")
        bands = ["#3557D6", "#7A3BD1", "#C04A9E", "#1F8FD8", "#5B6CF0"]
    else:
        top, bottom = hexrgb("#BFD9FF"), hexrgb("#F7D6E6")
        bands = ["#5B8CFF", "#9C7BFF", "#FF8FB8", "#5FC6FF", "#FFB27A"]
    base = Image.new("RGB", (w, h))
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        row = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = row
    img = base.convert("RGB")
    for k, col in enumerate(bands):
        # маска ленты: плавная синусоида; размываем только маску, без ореолов
        mask = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(mask)
        amp = h * (0.09 + 0.05 * rnd.random())
        freq = 0.6 + 0.5 * rnd.random()
        phase = rnd.random() * math.tau
        yc = h * (0.26 + 0.13 * k)
        thick = h * (0.20 + 0.06 * rnd.random())
        pts_top, pts_bot = [], []
        for x in range(-16, w + 24, 8):
            yy = yc + amp * math.sin(freq * x / w * math.tau + phase) + 0.35 * amp * math.sin(1.9 * x / w * math.tau + phase * 1.7)
            tk = thick * (0.75 + 0.25 * math.sin(0.9 * x / w * math.tau + phase * 0.5))
            pts_top.append((x, yy - tk / 2))
            pts_bot.append((x, yy + tk / 2))
        alpha = 0.60 if dark else 0.55
        d.polygon(pts_top + pts_bot[::-1], fill=int(255 * alpha))
        mask = mask.filter(ImageFilter.GaussianBlur(h * 0.06))
        img = Image.composite(Image.new("RGB", (w, h), hexrgb(col)), img, mask)
    img = img.filter(ImageFilter.GaussianBlur(3))
    # мягкая виньетка (в светлой — почти незаметная)
    vign = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vign).ellipse([-w * 0.3, -h * 0.4, w * 1.3, h * 1.4], fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(h * 0.18))
    darker = Image.blend(img, Image.new("RGB", (w, h), (0, 0, 0)), 0.35 if dark else 0.06)
    img = Image.composite(img, darker, vign)
    img = img.resize((W, H), Image.BICUBIC)
    # едва заметный шум — чтобы не было «лесенки» на градиенте
    noise = Image.effect_noise((W, H), 6).convert("RGB")
    img = Image.blend(img, noise, 0.025)
    img.save(path, quality=92)


# ----------------------------------------------------------------------------
# Значки
# ----------------------------------------------------------------------------
def settings_icon(path, size=128):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = S * 0.06
    d.rounded_rectangle([m, m, S - m, S - m], radius=S * 0.22, fill=hexrgb("#8E8E93") + (255,))
    d.rounded_rectangle([m * 1.6, m * 1.6, S - m * 1.6, S - m * 1.6], radius=S * 0.19, fill=hexrgb("#D1D1D6") + (255,))
    # шестерёнка
    c = S / 2
    R1, R2 = S * 0.30, S * 0.36
    teeth = 12
    pts = []
    for i in range(teeth * 2):
        ang = math.pi * i / teeth
        rr = R2 if i % 2 == 0 else R1
        pts.append((c + rr * math.cos(ang), c + rr * math.sin(ang)))
    d.polygon(pts, fill=hexrgb("#636366") + (255,))
    d.ellipse([c - R1 * 0.92, c - R1 * 0.92, c + R1 * 0.92, c + R1 * 0.92], fill=hexrgb("#636366") + (255,))
    d.ellipse([c - R1 * 0.42, c - R1 * 0.42, c + R1 * 0.42, c + R1 * 0.42], fill=hexrgb("#D1D1D6") + (255,))
    img.resize((size, size), Image.LANCZOS).save(path)


def main():
    for name, p in THEMES.items():
        out = os.path.join(ROOT, "icewm", name)
        os.makedirs(os.path.join(out, "taskbar"), exist_ok=True)
        build_icewm_buttons(name, p, out)
        write_theme_file(name, p, out)
        save_xpm(leaf_image(18, p["leaf"], p["bar"]), os.path.join(out, "taskbar", "start.xpm"))
        print("тема", name, "готова")

    os.makedirs(os.path.join(ROOT, "wallpapers"), exist_ok=True)
    wallpaper(os.path.join(ROOT, "wallpapers", "orchard-light.jpg"), dark=False)
    wallpaper(os.path.join(ROOT, "wallpapers", "orchard-dark.jpg"), dark=True)
    print("обои готовы")

    os.makedirs(os.path.join(ROOT, "icons"), exist_ok=True)
    settings_icon(os.path.join(ROOT, "icons", "orchard-settings.png"))
    leaf_image(128, "#34C759", None).save(os.path.join(ROOT, "icons", "orchard.png"))
    print("значки готовы")


if __name__ == "__main__":
    main()
