"""Одностраничный PDF-анонс Orbita для отправки в мессенджере."""

from pathlib import Path

from pptx import Presentation
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches

import build_deck as d

HERE = Path(__file__).resolve().parent
OUT = HERE / "Orbita_anons.pptx"

prs = Presentation()
prs.slide_width = Inches(8.27)
prs.slide_height = Inches(11.69)
s = prs.slides.add_slide(prs.slide_layouts[6])
fill = s.background.fill
fill.solid()
fill.fore_color.rgb = d.PAPER

# --- Шапка ----------------------------------------------------------------
d.rect(s, 0, 0, 8.27, 2.55, d.NAVY)
d.picture(s, d.ASSETS / "cat_anons_navy.png", 5.27, 0.18, h=2.25)

d.add_text(s, 0.6, 0.6, 4.8, 0.25, "МЕССЕНДЖЕР ДЛЯ СВОИХ", 8,
           d.RGBColor(0x8F, 0xB3, 0xCC), spc=220)
d.add_text(s, 0.55, 0.88, 4.9, 0.85, "Orbita", 48, d.WHITE, d.FONT_HEAD)
d.add_text(s, 0.6, 1.72, 4.8, 0.35, "Маленький. Личный. Наш.", 12.5,
           d.RGBColor(0xC9, 0xD8, 0xE4))
d.rect(s, 0.62, 2.14, 0.9, 0.045, d.PEACH)

# --- Заголовок и вступление ----------------------------------------------
d.add_text(s, 0.6, 2.92, 7.0, 1.05, "У нас теперь есть\nсвой мессенджер.",
           30, d.INK, d.FONT_HEAD, line_spacing=1.02)
d.add_text(s, 0.62, 4.02, 6.95, 0.9,
           "Я сделал Orbita — маленький мессенджер только для своих. "
           "Без рекламы, подписок и чужих алгоритмов. Только мы и наши сообщения. "
           "И первый человек, которому я его показываю, — ты.",
           10.8, d.GRAY, line_spacing=1.45)

# --- Возможности ----------------------------------------------------------
d.add_text(s, 0.62, 5.08, 4.0, 0.22, "ЧТО ВНУТРИ", 8.5, d.SKY, spc=180)
features = [
    ("Мгновенно", "Сообщения долетают сразу, без «обнови страницу».", d.SKY),
    ("Только для нас", "Сквозное шифрование: переписка между нами.", d.PEACH),
    ("Голосовые", "С перемоткой — можно слушать быстрее, чем я говорю.", d.GREEN),
    ("Своя атмосфера", "Тёмная тема, аккуратный интерфейс и ноль рекламы.", d.AMBER),
]
cw, ch = 3.35, 1.02
for i, (title, desc, tint) in enumerate(features):
    row, col = divmod(i, 2)
    x = 0.6 + col * (cw + 0.17)
    y = 5.35 + row * (ch + 0.14)
    d.card(s, x, y, cw, ch)
    d.circle(s, x + 0.18, y + 0.2, 0.1, tint)
    d.add_text(s, x + 0.4, y + 0.13, cw - 0.55, 0.25, title, 11.5, d.INK, d.FONT_HEAD)
    d.add_text(s, x + 0.18, y + 0.45, cw - 0.36, 0.45, desc, 8.6, d.GRAY, line_spacing=1.22)

# --- Как начать -----------------------------------------------------------
d.rect(s, 0.6, 7.95, 7.07, 1.42, d.NAVY, radius=0.12)
d.add_text(s, 0.86, 8.1, 4.0, 0.2, "КАК НАЧАТЬ", 8, d.RGBColor(0x8F, 0xB3, 0xCC), spc=180)
steps = [
    ("01", "Скажи «да»", "Пришлю ссылку и помогу установить."),
    ("02", "Зарегистрируйся", "По email, это займёт минуту."),
    ("03", "Напиши мне", "И мы перейдём в свой мессенджер."),
]
for i, (num, title, desc) in enumerate(steps):
    x = 0.86 + i * 2.25
    d.add_text(s, x, 8.38, 0.4, 0.3, num, 14, d.PEACH, d.FONT_HEAD)
    d.add_text(s, x + 0.42, 8.35, 1.75, 0.25, title, 10.2, d.WHITE, d.FONT_HEAD)
    d.add_text(s, x + 0.42, 8.63, 1.72, 0.55, desc, 8.2, d.RGBColor(0xC9, 0xD8, 0xE4),
               line_spacing=1.25)

# --- Личная подпись -------------------------------------------------------
note = d.add_text(s, 0.68, 9.72, 7.0, 0.65,
                  "Ты — первый пользователь Orbita.\nКроме меня, конечно.",
                  15.5, d.RGBColor(0xC9, 0x6A, 0x4A), d.FONT_HAND, line_spacing=1.15)
note.rotation = -2
sig = d.add_text(s, 0.7, 10.52, 7.0, 0.38, "С теплом, твой разработчик",
                 15, d.NAVY, d.FONT_HAND)
sig.rotation = -1.5

# --- Подвал ---------------------------------------------------------------
d.line(s, 0.6, 11.12, 7.67, 11.12, d.BORDER, 0.75)
d.add_text(s, 0.6, 11.19, 4.6, 0.2, "ORBITA · МЕССЕНДЖЕР ДЛЯ СВОИХ", 7.2, d.HINT, spc=100)
d.add_text(s, 4.9, 11.19, 2.77, 0.2, "Без рекламы и подписок", 7.2, d.HINT,
           align=PP_ALIGN.RIGHT)

prs.core_properties.title = "Orbita — мессенджер для своих"
prs.core_properties.author = "Твой разработчик"
prs.save(OUT)
print(f"saved {OUT}")
