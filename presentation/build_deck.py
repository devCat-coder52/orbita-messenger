"""Сборка шуточной презентации Orbita для одного очень важного человека."""

from pathlib import Path

from lxml import etree
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.dml import MSO_LINE_DASH_STYLE
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

HERE = Path(__file__).resolve().parent
ASSETS = HERE / "assets"
OUT = HERE / "Orbita_prezentaciya.pptx"

# --- Палитра приложения -----------------------------------------------------
NAVY = RGBColor(0x2C, 0x3E, 0x50)
NAVY_DEEP = RGBColor(0x22, 0x30, 0x3E)
NAVY_SOFT = RGBColor(0x3A, 0x4C, 0x60)
INK = RGBColor(0x1B, 0x27, 0x33)
SKY = RGBColor(0x34, 0x98, 0xDB)
SKY_DARK = RGBColor(0x21, 0x76, 0xAE)
SKY_SOFT = RGBColor(0xE3, 0xF2, 0xFD)
PAPER = RGBColor(0xF5, 0xF7, 0xFA)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
GRAY = RGBColor(0x50, 0x71, 0x92)
HINT = RGBColor(0x8F, 0xA2, 0xB3)
BORDER = RGBColor(0xE1, 0xE7, 0xED)
PEACH = RGBColor(0xE8, 0x83, 0x5E)
PEACH_SOFT = RGBColor(0xFB, 0xE3, 0xD9)
GREEN = RGBColor(0x2E, 0x7D, 0x32)
GREEN_SOFT = RGBColor(0xE8, 0xF5, 0xE9)
AMBER = RGBColor(0xF2, 0xA0, 0x4B)
AMBER_SOFT = RGBColor(0xFF, 0xF3, 0xE0)
LILAC_SOFT = RGBColor(0xEE, 0xE9, 0xF7)
DARK_TEXT = RGBColor(0xD8, 0xE4, 0xEE)
DARK_MUTED = RGBColor(0xAF, 0xC2, 0xD2)
DARK_LINE = RGBColor(0x3E, 0x52, 0x66)

FONT = "Segoe UI"
FONT_HEAD = "Segoe UI Semibold"
FONT_HAND = "Segoe Print"
FONT_EMOJI = "Segoe UI Emoji"

W = 13.333
H = 7.5
LEFT = 0.75
RIGHT = 12.58
CONTENT_W = RIGHT - LEFT


# --- Базовые помощники ------------------------------------------------------
def new_slide(prs, dark=False):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = NAVY if dark else PAPER
    return slide


def set_fill_alpha(shape, alpha):
    solid = shape.fill._xPr.find(qn("a:solidFill"))
    if solid is None:
        return
    clr = solid.find(qn("a:srgbClr"))
    if clr is None:
        return
    el = etree.SubElement(clr, qn("a:alpha"))
    el.set("val", str(int(alpha * 100000)))


def strip_style(shp):
    """Убирает ссылку на тему оформления, чтобы не было теней и лишних обводок."""
    style = shp._element.find(qn("p:style"))
    if style is not None:
        shp._element.remove(style)


def rect(slide, x, y, w, h, fill, line=None, radius=None, lw=1.0):
    shape_type = MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE
    shp = slide.shapes.add_shape(shape_type, Inches(x), Inches(y), Inches(w), Inches(h))
    strip_style(shp)
    shp.shadow.inherit = False
    if fill is None:
        shp.fill.background()
    else:
        shp.fill.solid()
        shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(lw)
    if radius:
        shp.adjustments[0] = min(0.5, radius / min(w, h))
    shp.text_frame.word_wrap = True
    return shp


def circle(slide, x, y, d, fill, line=None, lw=1.0):
    shp = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    strip_style(shp)
    shp.shadow.inherit = False
    if fill is None:
        shp.fill.background()
    else:
        shp.fill.solid()
        shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(lw)
    return shp


def _style_run(run, size, color, font, bold, italic, spc):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    if spc:
        run.font._rPr.set("spc", str(spc))


def add_text(slide, x, y, w, h, text, size=18, color=INK, font=FONT, bold=False,
             italic=False, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP,
             line_spacing=1.0, space_after=0, spc=None, shrink=False):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    lines = text.split("\n")
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.line_spacing = line_spacing
        p.space_after = Pt(space_after)
        run = p.add_run()
        run.text = line
        _style_run(run, size, color, font, bold, italic, spc)
    return box


def add_runs(slide, x, y, w, h, runs, size=18, color=INK, font=FONT,
             align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, spc=None):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    p = tf.paragraphs[0]
    p.alignment = align
    for text, opts in runs:
        run = p.add_run()
        run.text = text
        _style_run(
            run,
            opts.get("size", size),
            opts.get("color", color),
            opts.get("font", font),
            opts.get("bold", False),
            opts.get("italic", False),
            opts.get("spc", spc),
        )
    return box


def line(slide, x1, y1, x2, y2, color, width=1.0, dash=None):
    conn = slide.shapes.add_connector(
        MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2)
    )
    conn.line.color.rgb = color
    conn.line.width = Pt(width)
    if dash:
        conn.line.dash_style = dash
    return conn


def picture(slide, path, x, y, w=None, h=None):
    kw = {}
    if w:
        kw["width"] = Inches(w)
    if h:
        kw["height"] = Inches(h)
    return slide.shapes.add_picture(str(path), Inches(x), Inches(y), **kw)


def avatar(slide, x, y, h, ring=0.0, ring_color=WHITE):
    """Круглая аватарка Orbita; ring — белая окантовка для тёмного фона."""
    if ring:
        circle(slide, x - ring, y - ring, h + ring * 2, ring_color)
    picture(slide, ASSETS / "orbita.png", x, y, h=h)


def decor_ring(slide, dark=False):
    ring = circle(slide, 10.1, -2.0, 5.9, None, DARK_LINE if dark else RGBColor(0xE3, 0xEC, 0xF3), 1.25)
    return ring


def eyebrow(slide, number, label, dark=False):
    color = RGBColor(0x8F, 0xB3, 0xCC) if dark else SKY
    add_runs(
        slide, LEFT, 0.52, 8.0, 0.28,
        [
            (number, {"color": color, "bold": True, "spc": 160}),
            ("  ·  " + label, {"color": DARK_MUTED if dark else HINT, "spc": 160}),
        ],
        size=10.5,
    )


def footer(slide, number, dark=False):
    color = DARK_MUTED if dark else HINT
    line_color = DARK_LINE if dark else BORDER
    line(slide, LEFT, 7.06, RIGHT, 7.06, line_color, 0.75)
    add_text(slide, LEFT, 7.14, 5.0, 0.22, "ORBITA  ·  BETA 0.8.13", 8.5, color, spc=120)
    add_text(slide, RIGHT - 1.0, 7.14, 1.0, 0.22, f"{number:02d}", 8.5, color, align=PP_ALIGN.RIGHT)


def headline(slide, text, y=0.85, size=38, w=CONTENT_W, color=INK, h=1.35, x=LEFT):
    add_text(slide, x, y, w, h, text, size, color, FONT_HEAD, line_spacing=0.98)


def notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


def icon_badge(slide, x, y, d, emoji, fill, size=18, font=FONT_EMOJI, color=INK):
    circle(slide, x, y, d, fill)
    add_text(
        slide, x, y, d, d, emoji, size, color, font,
        align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE,
    )


def pill(slide, x, y, w, h, text, fill, color, size=11, bold=False, line_color=None):
    rect(slide, x, y, w, h, fill, line_color, radius=h / 2, lw=0.75)
    add_text(
        slide, x + 0.06, y, w - 0.12, h, text, size, color,
        bold=bold, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE,
    )


def card(slide, x, y, w, h, fill=WHITE, line_color=BORDER):
    return rect(slide, x, y, w, h, fill, line_color, radius=0.09, lw=0.75)


# --- Слайды -----------------------------------------------------------------
def slide_title(prs):
    s = new_slide(prs, dark=True)
    glow = circle(s, 8.2, -2.2, 8.2, RGBColor(0x33, 0x47, 0x5B))
    set_fill_alpha(glow, 0.3)

    add_text(s, 0.9, 0.72, 7.0, 0.28, "ПРЕЗЕНТАЦИЯ  ·  ВЕРСИЯ 0.8.13", 10.5,
             RGBColor(0x8F, 0xB3, 0xCC), spc=180)
    add_text(s, 0.82, 1.28, 7.0, 1.6, "Orbita", 96, WHITE, FONT_HEAD)
    add_text(s, 0.9, 2.92, 6.6, 0.6, "Мессенджер для своих.", 28, RGBColor(0xDC, 0xE7, 0xF0))
    rect(s, 0.92, 3.62, 1.15, 0.055, PEACH)

    add_text(
        s, 0.9, 3.86, 6.2, 1.2,
        "Маленький, свой, с котиком на иконке.\n"
        "Эта презентация — для одного человека.\nТы уже поняла, для кого.",
        15.5, RGBColor(0xB4, 0xC7, 0xD7), line_spacing=1.35,
    )

    note = add_text(
        s, 0.94, 5.5, 6.0, 0.8,
        "Да, я сделал это сам.\nНет, я не спал неделю.",
        19, PEACH, FONT_HAND, line_spacing=1.15,
    )
    note.rotation = -3

    add_text(s, 0.9, 6.62, 6.4, 0.3,
             "Android · iOS · Windows · Linux · Web      0 рекламы · 0 подписок",
             10.5, RGBColor(0x8F, 0xA6, 0xB8), spc=40)

    avatar(s, 8.45, 1.4, 4.6)
    notes(s, "Привет! Это не отчёт за квартал, а презентация моего мессенджера. "
             "Точнее, нашего — сейчас поймёшь. Да, котик настоящий: теперь он официальный символ Orbita.")


def slide_problem(prs):
    s = new_slide(prs)
    decor_ring(s)
    eyebrow(s, "01", "ЗАЧЕМ")
    headline(s, "Наша переписка живёт у чужих дядек.", size=40, h=0.8)
    add_text(
        s, LEFT, 1.72, 9.6, 0.8,
        "Я посмотрел на это и подумал: у меня есть ноутбук, свободные вечера "
        "и подозрительно много терпения.",
        15.5, GRAY, line_spacing=1.3,
    )

    data = [
        ("☁️", "Чужие серверы", "Наши «доброе утро» хранятся где-то в другом полушарии. Мне от этого неуютно."),
        ("⚙️", "Чужие правила", "Алгоритм решает, что мне показывать. Я не люблю, когда решают за меня."),
        ("🔧", "Чужой код", "Сломалось — пиши в поддержку. А я хочу чинить сам. Ну, или хотя бы пытаться."),
    ]
    cw = 3.78
    for i, (emoji, title, desc) in enumerate(data):
        x = LEFT + i * (cw + 0.25)
        card(s, x, 2.68, cw, 2.35)
        icon_badge(s, x + 0.26, 2.94, 0.56, emoji, SKY_SOFT, 19)
        add_text(s, x + 0.26, 3.66, cw - 0.52, 0.35, title, 17.5, INK, FONT_HEAD)
        add_text(s, x + 0.26, 4.04, cw - 0.5, 0.85, desc, 12.5, GRAY, line_spacing=1.25)

    banner = rect(s, LEFT, 5.35, CONTENT_W, 0.78, PEACH_SOFT, radius=0.08)
    rect(s, LEFT, 5.35, 0.07, 0.78, PEACH, radius=0.03)
    add_text(
        s, LEFT + 0.32, 5.35, CONTENT_W - 0.5, 0.78,
        "Поэтому я сделал свой мессенджер. Это была не самая дешёвая идея — по времени.",
        15.5, RGBColor(0x8A, 0x4A, 0x33), anchor=MSO_ANCHOR.MIDDLE,
    )
    note = add_text(s, 0.92, 6.42, 5.0, 0.35, "венчурные инвесторы: я сам",
                    16, HINT, FONT_HAND)
    note.rotation = -2
    footer(s, 2)
    notes(s, "Начну с проблемы. Наша переписка хранится у большой компании, и мне это не нравится. "
             "Не из паранойи, а из принципа: я программист, я хочу чинить своё. "
             "Спонсоров у проекта пока нет — только я и ночи.")


def slide_intro(prs):
    s = new_slide(prs)
    eyebrow(s, "02", "ЗНАКОМЬСЯ")
    headline(s, "Orbita — мессенджер, который мы теперь тестируем вдвоём.", size=33, w=8.2)
    add_text(
        s, LEFT, 2.28, 7.7, 1.0,
        "Название — от орбиты: чтобы наше общение не зависело от чужой компании. "
        "Котик — потому что ты любишь котиков. Всё продумано.",
        15, GRAY, line_spacing=1.3,
    )

    chips = ["Мгновенные сообщения", "Сквозное шифрование", "Голосовые",
             "Фото и файлы", "Тёмная тема", "Без рекламы"]
    for i, text in enumerate(chips):
        row, col = divmod(i, 3)
        x = LEFT + col * 2.62
        y = 3.55 + row * 0.52
        pill(s, x, y, 2.5, 0.4, text, WHITE, INK, 11, line_color=BORDER)

    rect(s, LEFT, 5.0, 0.06, 1.05, SKY, radius=0.03)
    add_text(
        s, LEFT + 0.28, 5.0, 7.3, 1.1,
        "«Для своих» здесь — буквально.\nКроме нас там пока никого.",
        21, INK, FONT_HEAD, line_spacing=1.15,
    )

    picture(s, ASSETS / "orbita.png", 9.45, 1.08, h=3.7)
    rect(s, 9.18, 4.92, 3.25, 0.74, WHITE, BORDER, radius=0.16)
    add_text(s, 9.18, 4.92, 3.25, 0.74, "Мяу. То есть — привет.",
             12.5, GRAY, FONT_HAND, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    footer(s, 3)
    notes(s, "Знакомься, это Orbita. Название — от орбиты, чтобы наше общение было на своей орбите. "
             "Котик — потому что ты любишь котиков. Логика железная. "
             "Пока это бета, но бета с характером.")


def slide_features(prs):
    s = new_slide(prs)
    decor_ring(s)
    eyebrow(s, "03", "ЧТО УМЕЕТ")
    headline(s, "Шесть причин, чтобы остаться здесь.", size=38, h=0.8)

    data = [
        ("⚡", "Долетает мгновенно", "Быстрее, чем ты успеешь передумать и удалить сообщение.", SKY_SOFT),
        ("💬", "«Печатает…»", "Три точки, которые честно врут, что я уже придумал ответ.", AMBER_SOFT),
        ("🎙️", "Голосовые", "С перемоткой. Как мои объяснения, только можно промотать.", PEACH_SOFT),
        ("↩", "Ответ свайпом", "Цитируй мои лучшие фразы. Да, все. Я не против.", GREEN_SOFT),
        ("🔍", "Поиск", "Найдёт то самое сообщение, даже если ты забыла, где оно.", LILAC_SOFT),
        ("🌙", "Тёмная тема", "Для переписки в три ночи, когда весь мир спит. И я тоже.", SKY_SOFT),
    ]
    cw = 3.78
    ch = 1.95
    for i, (emoji, title, desc, tint) in enumerate(data):
        row, col = divmod(i, 3)
        x = LEFT + col * (cw + 0.25)
        y = 2.1 + row * (ch + 0.22)
        card(s, x, y, cw, ch)
        if emoji == "↩":
            icon_badge(s, x + 0.25, y + 0.22, 0.5, emoji, tint, 24, font=FONT, color=SKY_DARK)
        else:
            icon_badge(s, x + 0.25, y + 0.22, 0.5, emoji, tint, 18)
        add_text(s, x + 0.25, y + 0.86, cw - 0.5, 0.3, title, 16.5, INK, FONT_HEAD)
        add_text(s, x + 0.25, y + 1.25, cw - 0.48, 0.62, desc, 12.3, GRAY, line_spacing=1.25)

    add_text(s, 0.9, 6.5, 8.0, 0.35,
             "И да, всё это работает. Я проверял. Несколько раз. Ночью.",
             14, HINT, FONT_HAND)
    footer(s, 4)
    notes(s, "Вот шесть функций. Про «печатает…» — это не баг, это честно: я часто печатаю, "
             "стираю и печатаю снова. Голосовые можно перематывать — очень удобно, когда я "
             "объясняю что-то третий раз.")


def phone_mockup(s):
    x, y, w, h = 0.9, 0.85, 3.4, 5.95
    rect(s, x, y, w, h, RGBColor(0x16, 0x21, 0x2D), radius=0.22)
    sx, sy, sw, sh = x + 0.07, y + 0.07, w - 0.14, h - 0.14
    rect(s, sx, sy, sw, sh, PAPER, radius=0.17)
    header_h = 0.74
    rect(s, sx, sy, sw, header_h, NAVY, radius=0.17)
    rect(s, sx, sy + header_h - 0.18, sw, 0.18, NAVY)
    avatar(s, sx + 0.165, sy + 0.145, 0.43, ring=0.025)
    add_text(s, sx + 0.7, sy + 0.14, 1.4, 0.24, "Ты", 12, WHITE, FONT_HEAD)
    circle(s, sx + 0.72, sy + 0.44, 0.08, RGBColor(0x5C, 0xD6, 0x7A))
    add_text(s, sx + 0.86, sy + 0.38, 1.4, 0.2, "в сети", 8, RGBColor(0xA8, 0xC8, 0xE0))
    add_text(s, sx + sw - 0.55, sy + 0.25, 0.4, 0.22, "⋯", 16, RGBColor(0xC9, 0xD6, 0xE2))

    add_text(s, sx, sy + 0.9, sw, 0.2, "Сегодня", 7.5, HINT, align=PP_ALIGN.CENTER)

    def bubble(top, height, text, mine, when, width):
        if mine:
            bx = sx + sw - 0.12 - width
            fill = RGBColor(0xE3, 0xF2, 0xFD)
        else:
            bx = sx + 0.12
            fill = RGBColor(0xEC, 0xF1, 0xF5)
        rect(s, bx, top, width, height, fill, None, radius=0.14)
        add_text(s, bx + 0.12, top + 0.08, width - 0.24, height - 0.26,
                 text, 9.2, INK, line_spacing=1.15)
        add_text(s, bx + 0.1, top + height - 0.21, width - 0.2, 0.16,
                 when, 6.3, HINT, align=PP_ALIGN.RIGHT)

    bubble(sy + 1.18, 0.44, "Привет! Это правда твой мессенджер?", False, "21:04", 2.55)
    bubble(sy + 1.68, 0.42, "Правда. Только наш.", True, "21:04", 1.95)
    bubble(sy + 2.16, 0.42, "И котик на иконке — тоже мой.", True, "21:05", 2.42)
    bubble(sy + 2.64, 0.44, "Котик решает. А что он умеет?", False, "21:05", 2.5)
    bubble(sy + 3.14, 0.62, "Доставлять сообщения. И иногда доводить тебя до улыбки.",
           True, "21:06", 2.6)
    bubble(sy + 3.82, 0.44, "Тогда я остаюсь 🐱", False, "21:06", 2.1)

    # «печатает…»
    ty = sy + 4.36
    rect(s, sx + 0.12, ty, 0.98, 0.28, RGBColor(0xEC, 0xF1, 0xF5), None, radius=0.14)
    for i in range(3):
        circle(s, sx + 0.26 + i * 0.2, ty + 0.1, 0.075, HINT)
    add_text(s, sx + 1.18, ty + 0.03, 1.5, 0.2, "Ты печатает…", 6.8, HINT)

    # поле ввода
    iy = sy + sh - 0.52
    rect(s, sx + 0.1, iy, sw - 0.2, 0.4, WHITE, BORDER, radius=0.2)
    add_text(s, sx + 0.24, iy, sw - 0.75, 0.4, "Написать сообщение…", 8.2, HINT,
             anchor=MSO_ANCHOR.MIDDLE)
    circle(s, sx + sw - 0.48, iy + 0.04, 0.32, SKY)
    add_text(s, sx + sw - 0.48, iy + 0.04, 0.32, 0.32, "➤", 10, WHITE,
             align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)


def slide_demo(prs):
    s = new_slide(prs)
    eyebrow(s, "04", "КАК ЭТО ВЫГЛЯДИТ")
    headline(s, "Вот так. Только с твоими сообщениями — красивее.",
             size=34, w=7.5, h=1.4, x=5.05)
    phone_mockup(s)

    items = [
        ("01", "Мгновенно", "Сообщение уходит по сокету, а не «когда-нибудь»."),
        ("02", "Честные статусы", "Отправлено, доставлено, прочитано. Без «увидел и убежал»."),
        ("03", "Живой чат", "«Печатает…», онлайн и «был(а) недавно» — как у больших."),
    ]
    for i, (num, title, desc) in enumerate(items):
        y = 2.55 + i * 1.05
        add_text(s, 5.05, y, 0.45, 0.28, num, 10.5, PEACH, bold=True, spc=80)
        add_text(s, 5.55, y - 0.04, 6.9, 0.3, title, 18.5, INK, FONT_HEAD)
        add_text(s, 5.55, y + 0.34, 6.9, 0.4, desc, 13.2, GRAY, line_spacing=1.2)

    q = rect(s, 5.05, 5.72, 7.2, 0.92, PEACH_SOFT, radius=0.1)
    add_text(s, 5.27, 5.72, 6.8, 0.92,
             "Сейчас здесь пусто. Это ненадолго.", 16, RGBColor(0x8A, 0x4A, 0x33),
             FONT_HAND, anchor=MSO_ANCHOR.MIDDLE)
    footer(s, 5)
    notes(s, "Так выглядит чат. Сообщения здесь ненастоящие, но интерфейс вполне рабочий — "
             "можешь проверить, я не обижусь. Обрати внимание на статусы: всё честно, "
             "никаких «увидел и убежал».")


def slide_how(prs):
    s = new_slide(prs)
    eyebrow(s, "05", "МЕХАНИКА")
    headline(s, "Три шага. Ноль магии.", size=40, h=0.8)
    add_text(s, LEFT, 1.7, 9.5, 0.6,
             "От твоего «привет» до моего «привет» — примерно сорок миллисекунд.",
             15, GRAY)

    steps = [
        ("01", "Ты пишешь", "Телефон шифрует текст. Ключ остаётся у тебя, а не на сервере.", "📱", SKY_SOFT),
        ("02", "Сервер передаёт", "Node.js и Socket.IO доставляют сообщение за миллисекунды.", "☁️", AMBER_SOFT),
        ("03", "Я читаю", "И сразу вижу три точки: ты печатаешь. Иногда раньше текста.", "👀", PEACH_SOFT),
    ]
    cw = 3.62
    for i, (num, title, desc, emoji, tint) in enumerate(steps):
        x = LEFT + i * (cw + 0.49)
        card(s, x, 2.5, cw, 2.85)
        add_text(s, x + 0.3, 2.68, 1.2, 0.75, num, 42, PEACH, FONT_HEAD)
        add_text(s, x + 0.3, 3.5, cw - 0.6, 0.35, title, 20, INK, FONT_HEAD)
        add_text(s, x + 0.3, 3.93, cw - 0.55, 1.2, desc, 13.2, GRAY, line_spacing=1.3)
        icon_badge(s, x + cw - 0.78, 4.55, 0.5, emoji, tint, 18)
        if i < 2:
            add_text(s, x + cw + 0.04, 3.75, 0.42, 0.5, "→", 25, SKY, align=PP_ALIGN.CENTER)

    add_text(s, 0.9, 5.72, 10.8, 0.5,
             "Между шагами есть база, миграции и Redis. Но ты же не хочешь слушать про миграции.",
             13, HINT, FONT_HAND)
    footer(s, 6)
    notes(s, "Три шага: телефон шифрует, сервер передаёт, я читаю. Магии нет — есть сокеты "
             "и немного нервов. Сорок миллисекунд — это быстрее, чем я успеваю придумать ответ.")


def slide_stack(prs):
    s = new_slide(prs)
    decor_ring(s)
    eyebrow(s, "06", "ПОД КАПОТОМ")
    headline(s, "Что внутри. Объясняю без занудства.", size=36, h=0.8)

    rows = [
        ("F", "Flutter", "Один код — пять платформ: Android, iOS, Windows, Linux и Web.", SKY),
        ("N", "Node.js + Socket.IO", "Курьер, который не спит и приносит сообщения мгновенно.", GREEN),
        ("P", "PostgreSQL", "Шкаф с перепиской: всё по полочкам, ничего не теряется.", NAVY),
        ("R", "Redis", "Секретарь, который хранит коды подтверждения и не даёт спамить.", RGBColor(0xD8, 0x2C, 0x20)),
        ("FB", "Firebase", "Почтальон, который стучится в телефон, даже если приложение закрыто.", AMBER),
    ]
    y = 1.95
    for letter, name, desc, tint in rows:
        card(s, LEFT, y, CONTENT_W, 0.76)
        rect(s, LEFT + 0.16, y + 0.14, 0.48, 0.48, tint, radius=0.1)
        add_text(s, LEFT + 0.16, y + 0.14, 0.48, 0.48, letter, 16 if len(letter) > 1 else 19,
                 WHITE, FONT_HEAD, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        add_text(s, LEFT + 0.82, y, 2.4, 0.76, name, 14.5, INK, FONT_HEAD, anchor=MSO_ANCHOR.MIDDLE)
        add_text(s, LEFT + 3.3, y, 8.3, 0.76, desc, 12.5, GRAY, anchor=MSO_ANCHOR.MIDDLE)
        y += 0.86

    add_text(s, 0.9, 6.42, 10.5, 0.35,
             "Ещё JWT, bcrypt и миграции. Но про них — отдельная презентация. Для мамы.",
             12.5, HINT, FONT_HAND)
    footer(s, 7)
    notes(s, "Немного технологий. Если станет скучно — просто кивай, я привык. "
             "Flutter — один код на все платформы. Postgres — шкаф с перепиской. "
             "Redis — секретарь с кодами. Firebase — почтальон.")


def slide_privacy(prs):
    s = new_slide(prs, dark=True)
    glow = circle(s, 10.4, -1.4, 5.4, RGBColor(0x35, 0x49, 0x5D))
    set_fill_alpha(glow, 0.3)
    eyebrow(s, "07", "ПРИВАТНОСТЬ", dark=True)
    headline(s, "Твои сообщения — только твои.", size=40, color=WHITE, h=0.8)
    add_text(s, LEFT, 1.72, 10.8, 0.5,
             "Сквозное шифрование: сервер видит шифротекст, а не «привет, как дела».",
             17.5, DARK_TEXT)

    data = [
        ("🔑", "Ключи — на телефоне", "У каждого свои. Не в облаке и не у меня в блокноте."),
        ("🚫", "Чужие чаты закрыты", "Даже с моим доступом не откроешь переписку по номеру."),
        ("↻", "Смена пароля", "Все старые устройства выходят из аккаунта. Сразу."),
        ("📎", "Файлы под контролем", "Только картинки и аудио. Никаких .exe с сюрпризом."),
    ]
    cw = 5.79
    for i, (emoji, title, desc) in enumerate(data):
        row, col = divmod(i, 2)
        x = LEFT + col * (cw + 0.25)
        y = 2.55 + row * 1.78
        card(s, x, y, cw, 1.6, NAVY_SOFT, RGBColor(0x4A, 0x5E, 0x72))
        if emoji == "↻":
            icon_badge(s, x + 0.24, y + 0.26, 0.48, emoji, RGBColor(0x46, 0x5A, 0x6E), 22,
                       font=FONT, color=RGBColor(0xA8, 0xC8, 0xE0))
        else:
            icon_badge(s, x + 0.24, y + 0.26, 0.48, emoji, RGBColor(0x46, 0x5A, 0x6E), 17)
        add_text(s, x + 0.86, y + 0.25, cw - 1.1, 0.3, title, 16.5, WHITE, FONT_HEAD)
        add_text(s, x + 0.86, y + 0.68, cw - 1.1, 0.7, desc, 12.2, DARK_MUTED, line_spacing=1.25)

    add_text(s, 0.9, 6.35, 9.0, 0.4,
             "Паранойя — это просто внимательность с опытом.", 15, PEACH, FONT_HAND)
    footer(s, 8, dark=True)
    notes(s, "Про безопасность коротко: ключи у тебя, чужие чаты закрыты. "
             "Даже я не могу прочитать твои сообщения. Теоретически. На практике не проверял.")


def slide_beta(prs):
    s = new_slide(prs)
    eyebrow(s, "08", "ЧЕСТНО О БЕТЕ")
    headline(s, "Чего пока нет. Говорю как есть.", size=38, h=0.8)

    data = [
        ("👥", "Групповых чатов", "Но нам и вдвоём неплохо. Правда?"),
        ("📞", "Звонков", "Пока только текстом. Как в лучших домах XIX века."),
        ("❤️", "Реакций", "Сердечко — отдельным сообщением. Как в письмах. Старомодно, зато искренне."),
        ("📱", "Мультиустройства", "Один телефон — один я. Как в жизни."),
    ]
    y = 2.08
    for emoji, title, desc in data:
        card(s, LEFT, y, CONTENT_W, 0.86)
        icon_badge(s, LEFT + 0.2, y + 0.16, 0.52, emoji, PEACH_SOFT, 18)
        add_text(s, LEFT + 0.92, y, 3.2, 0.86, title, 18, INK, FONT_HEAD, anchor=MSO_ANCHOR.MIDDLE)
        add_text(s, LEFT + 4.2, y, 6.0, 0.86, desc, 13, GRAY, anchor=MSO_ANCHOR.MIDDLE)
        pill(s, RIGHT - 1.38, y + 0.26, 1.18, 0.34, "пока нет", PEACH_SOFT,
             RGBColor(0x8A, 0x4A, 0x33), 10.5)
        y += 0.96

    strip = rect(s, LEFT, 6.08, CONTENT_W, 0.66, NAVY, radius=0.09)
    add_runs(
        s, LEFT + 0.3, 6.08, CONTENT_W - 0.6, 0.66,
        [
            ("Зато: 0 рекламы  ·  0 подписок  ·  0 трекеров   ", {"color": WHITE}),
            ("и 1 разработчик", {"color": PEACH}),
            (", который всё чинит ночью.", {"color": WHITE}),
        ],
        size=13.5, anchor=MSO_ANCHOR.MIDDLE,
    )
    footer(s, 9)
    notes(s, "Честно о бете. Групповых чатов нет, звонков нет, реакций нет. "
             "Зато нет рекламы, подписок и сбора данных. Один разработчик — это я. "
             "Он же поддержка, он же дизайнер, он же тот, кто чинит в три ночи.")


def slide_numbers(prs):
    s = new_slide(prs, dark=True)
    eyebrow(s, "09", "ЦИФРЫ", dark=True)
    headline(s, "Немного цифр для солидности.", size=40, color=WHITE, h=0.8)
    add_text(s, LEFT, 1.72, 10.0, 0.5,
             "Чтобы презентация выглядела как у взрослых компаний.", 15, DARK_MUTED)

    stats = [
        ("1", "разработчик.\nИ он очень старался."),
        ("5", "платформы:\nAndroid, iOS, Windows, Linux, Web."),
        ("0 ₽", "подписка.\nНавсегда. Пока я жив."),
        ("20 МБ", "максимальный файл.\nХватит на фото котика."),
    ]
    col_w = CONTENT_W / 4
    for i, (num, label) in enumerate(stats):
        x = LEFT + i * col_w
        if i:
            line(s, x - 0.12, 2.55, x - 0.12, 4.85, DARK_LINE, 1.0)
        add_text(s, x, 2.5, col_w - 0.3, 1.05, num, 64, PEACH if i == 2 else WHITE, FONT_HEAD)
        add_text(s, x, 3.78, col_w - 0.4, 1.0, label, 13.2, DARK_TEXT, line_spacing=1.25)

    add_text(s, 0.9, 5.35, 10.5, 0.5,
             "Самая важная метрика — ты сейчас это читаешь.", 21, DARK_TEXT)
    note = add_text(s, 0.92, 6.3, 6.0, 0.4, "инвестиции: бессонные ночи", 16,
                    RGBColor(0x8F, 0xA6, 0xB8), FONT_HAND)
    note.rotation = -2
    footer(s, 10, dark=True)
    notes(s, "Цифры для солидности. Единица — это я. Пять — платформы. Ноль — реклама и подписка. "
             "Двадцать мегабайт — хватит на фото котика. Всё сходится.")


def slide_roadmap(prs):
    s = new_slide(prs)
    eyebrow(s, "10", "ЧТО ДАЛЬШЕ")
    headline(s, "Планы на версию 1.0", size=38, h=0.8)
    add_text(s, LEFT, 1.68, 9.5, 0.5,
             "Обещать — не значит сделать. Но направление покажу.", 15, GRAY)

    stages = [
        ("СЕЙЧАС", "Бета 0.8.13", "Работает, иногда падает, снова работает. Как и я."),
        ("СКОРО", "Звонки и группы", "Чтобы можно было болтать не только вдвоём. Но я не против и вдвоём."),
        ("ПОТОМ", "Реакции", "Сердечко в один тап. Наконец-то."),
        ("МЕЧТА", "Ты открываешь Orbita", "Не потому что я попросил, а потому что нравится."),
    ]
    line(s, 1.4, 3.6, 11.75, 3.6, RGBColor(0xD5, 0xE1, 0xEB), 2.0)
    for i, (stage, title, desc) in enumerate(stages):
        cx = 1.7 + i * 2.8
        add_text(s, cx - 0.1, 2.55, 2.6, 0.25, stage, 10, SKY, bold=True, spc=140)
        circle(s, cx, 3.44, 0.32, PAPER, SKY, 2.0)
        circle(s, cx + 0.09, 3.53, 0.14, SKY)
        add_text(s, cx - 0.1, 3.9, 2.65, 0.6, title, 16.5, INK, FONT_HEAD, line_spacing=1.05)
        add_text(s, cx - 0.1, 4.55, 2.65, 0.95, desc, 11.8, GRAY, line_spacing=1.25)

    cta = rect(s, LEFT, 5.68, CONTENT_W, 0.98, PEACH_SOFT, radius=0.1)
    rect(s, LEFT, 5.68, 0.07, 0.98, PEACH, radius=0.03)
    add_text(s, LEFT + 0.3, 5.68, 5.9, 0.98, "Стань первым тестировщиком.",
             18, RGBColor(0x8A, 0x4A, 0x33), FONT_HEAD, anchor=MSO_ANCHOR.MIDDLE)
    add_text(s, 6.6, 5.68, 5.7, 0.98,
             "Скажи «да» — и я пришлю APK.\nСкажи «нет» — пришлю всё равно.",
             12.5, RGBColor(0x8A, 0x4A, 0x33), line_spacing=1.2, anchor=MSO_ANCHOR.MIDDLE)
    footer(s, 11)
    notes(s, "Планы. Обещать не буду, но направление покажу. Ближе всего — звонки и группы. "
             "Дальше реакции. А в идеале — ты открываешь Orbita не потому, что я попросил, "
             "а потому что тебе нравится.")


def slide_final(prs):
    s = new_slide(prs, dark=True)
    glow = circle(s, 8.4, -2.0, 7.4, RGBColor(0x33, 0x47, 0x5B))
    set_fill_alpha(glow, 0.3)
    eyebrow(s, "P.S.", "ФИНАЛ", dark=True)
    headline(s, "Спасибо,\nчто досмотрела.", y=1.8, size=44, w=7.3, color=WHITE, h=1.75)
    add_text(s, 0.9, 3.72, 7.0, 1.0,
             "Теперь ты официально первый пользователь Orbita.\nИ самый важный.",
             18, DARK_TEXT, line_spacing=1.35)
    add_text(s, 0.9, 5.0, 7.0, 0.8,
             "P.S. Котик на иконке — потому что ты любишь котиков.\nЯ всё продумал.",
             12.8, DARK_MUTED, line_spacing=1.4)
    add_text(s, 0.9, 5.78, 7.0, 0.8,
             "P.P.S. Групповых чатов пока нет. Но у нас и так только мы.",
             12.8, DARK_MUTED, line_spacing=1.4)
    sig = add_text(s, 0.94, 6.5, 6.5, 0.4, "С любовью, твой разработчик",
                   18, PEACH, FONT_HAND)
    sig.rotation = -2
    avatar(s, 8.45, 1.4, 4.6)
    notes(s, "Спасибо, что досмотрела. Ты официально первый пользователь Orbita. И самый важный. "
             "Котик на иконке — потому что ты любишь котиков. Я всё продумал.")


def main():
    prs = Presentation()
    prs.slide_width = Inches(W)
    prs.slide_height = Inches(H)
    prs.core_properties.title = "Orbita — мессенджер для своих"
    prs.core_properties.author = "Твой разработчик"
    prs.core_properties.subject = "Шуточная презентация мессенджера Orbita"
    prs.core_properties.comments = "Сделано с любовью и котиком."

    slide_title(prs)
    slide_problem(prs)
    slide_intro(prs)
    slide_features(prs)
    slide_demo(prs)
    slide_how(prs)
    slide_stack(prs)
    slide_privacy(prs)
    slide_beta(prs)
    slide_numbers(prs)
    slide_roadmap(prs)
    slide_final(prs)

    prs.save(OUT)
    print(f"saved {OUT} ({len(prs.slides)} slides)")


if __name__ == "__main__":
    main()
