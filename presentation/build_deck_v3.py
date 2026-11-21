"""Orbita: техническая презентация v3 — с анимациями и новой структурой."""

from pathlib import Path

from lxml import etree
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

import build_deck as d

HERE = Path(__file__).resolve().parent
ASSETS = HERE / "assets"
OUT = HERE / "Orbita_prezentaciya.pptx"

W, H = 13.333, 7.5
INK, GRAY, WHITE, PAPER = d.INK, d.GRAY, d.WHITE, d.PAPER
NAVY, SKY, PEACH, BORDER, HINT = d.NAVY, d.SKY, d.PEACH, d.BORDER, d.HINT


def notes(s, text):
    s.notes_slide.notes_text_frame.text = text


def headline(s, text, y=0.82, size=36, w=d.CONTENT_W, color=INK, h=1.35, x=d.LEFT):
    d.add_text(s, x, y, w, h, text, size, color, d.FONT_HEAD, line_spacing=0.98)


def app_icon(s, x, y, h):
    d.picture(s, ASSETS / "app_icon.png", x, y, h=h)


def app_mark(s, x, y, h):
    d.picture(s, ASSETS / "app_icon_mark.png", x, y, h=h)


ICON_FILES = {
    "flutter": "flutter.png",
    "dart": "dart.png",
    "node": "node.png",
    "express": "express.png",
    "npm": "npm.png",
    "postgres": "postgres.png",
    "redis": "redis.png",
    "socketio": "socketio.png",
    "firebase": "firebase.png",
    "jwt": "jwt.png",
    "lock": "lock.png",
}


def tech_icon(s, x, y, size, key, dark=False, tile=True, tile_fill=WHITE):
    pad = size * 0.14 if tile else 0
    if tile:
        line = d.RGBColor(0x6B, 0x7F, 0x92) if dark else d.BORDER
        d.rect(s, x, y, size, size, tile_fill, line, radius=size * 0.18, lw=0.75)
    d.picture(s, ASSETS / "icons" / ICON_FILES[key], x + pad, y + pad,
              w=size - 2 * pad, h=size - 2 * pad)


# --------------------------------------------------------------------------
# 1. Титул
# --------------------------------------------------------------------------
def title_slide(prs):
    s = d.new_slide(prs, dark=True)

    d.add_text(s, 0.9, 0.72, 7.5, 0.28, "ТЕХНИЧЕСКИЙ РАЗБОР  ·  ВЕРСИЯ 0.8.13",
               10.5, d.RGBColor(0x8F, 0xB3, 0xCC), spc=180)
    d.add_text(s, 0.82, 1.28, 7.0, 1.6, "Orbita", 96, WHITE, d.FONT_HEAD)
    d.add_text(s, 0.9, 2.92, 6.6, 0.6, "Мессенджер для своих.", 28,
               d.RGBColor(0xDC, 0xE7, 0xF0))
    d.rect(s, 0.92, 3.62, 1.15, 0.055, PEACH)
    d.add_text(s, 0.9, 3.9, 6.1, 1.0,
               "Как устроен мессенджер:\nот первого сообщения до push-уведомления.",
               16.5, d.RGBColor(0xB4, 0xC7, 0xD7), line_spacing=1.38)
    d.add_text(s, 0.9, 6.62, 7.2, 0.3,
               "Flutter · Node.js · PostgreSQL · Socket.IO · Firebase",
               10.5, d.RGBColor(0x8F, 0xA6, 0xB8), spc=30)
    app_mark(s, 8.8, 1.9, 4.0)
    notes(s, "Сегодня разберу Orbita по частям: что это, почему выбран такой стек, "
             "какие четыре технологии держат всё на себе и как выглядит масштаб проекта. "
             "Без маркетинга — только то, что реально работает.")


# --------------------------------------------------------------------------
# 2. Краткий обзор — только схема
# --------------------------------------------------------------------------
def overview_slide(prs):
    s = d.new_slide(prs)
    d.circle(s, 1.6, -2.2, 9.5, None, d.RGBColor(0xE5, 0xED, 0xF4), 1.2)
    d.circle(s, 9.2, 3.4, 6.2, None, d.RGBColor(0xEB, 0xF1, 0xF6), 1.0)

    def tree_node(x, y, w, h, icon_key, title, sub, icon_d=0.66):
        d.card(s, x, y, w, h)
        tech_icon(s, x + 0.16, y + (h - icon_d) / 2, icon_d, icon_key, tile=False)
        d.add_text(s, x + 0.16 + icon_d + 0.14, y + 0.16, w - icon_d - 0.4, 0.28,
                   title, 14.5, INK, d.FONT_HEAD)
        d.add_text(s, x + 0.16 + icon_d + 0.14, y + 0.46, w - icon_d - 0.35, 0.22,
                   sub, 8.5, GRAY)

    # Корень
    d.card(s, 0.8, 2.7, 2.0, 1.7)
    app_icon(s, 0.96, 2.88, 0.8)
    d.add_text(s, 1.0, 3.78, 1.65, 0.3, "Orbita", 16, INK, d.FONT_HEAD)
    d.add_text(s, 1.0, 4.08, 1.65, 0.2, "мессенджер", 8.5, GRAY)

    # Ветки
    d.line(s, 2.8, 3.55, 3.45, 3.55, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    d.line(s, 3.45, 2.2, 3.45, 5.55, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    d.line(s, 3.45, 2.2, 4.0, 2.2, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    d.line(s, 3.45, 5.55, 4.0, 5.55, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)

    tree_node(4.0, 1.55, 2.35, 1.3, "flutter", "Flutter", "клиент")
    tree_node(4.0, 4.9, 2.35, 1.3, "node", "Node.js", "сервер")

    # Flutter → Dart
    d.line(s, 6.35, 2.2, 7.2, 2.2, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    tree_node(7.2, 1.55, 2.35, 1.3, "dart", "Dart", "язык")

    # Node.js → его экосистема
    d.line(s, 6.35, 5.55, 6.95, 5.55, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    d.line(s, 6.95, 4.11, 6.95, 5.91, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
    leaves = [
        (3.75, "express", "Express", "HTTP"),
        (4.65, "socketio", "Socket.IO", "realtime"),
        (5.55, "npm", "npm", "пакеты"),
    ]
    for y, key, title, sub in leaves:
        d.line(s, 6.95, y + 0.36, 7.4, y + 0.36, d.RGBColor(0xC9, 0xD8, 0xE4), 2.0)
        d.card(s, 7.4, y, 3.1, 0.72)
        tech_icon(s, 7.52, y + 0.12, 0.48, key, tile=False)
        d.add_text(s, 8.1, y + 0.08, 2.2, 0.24, title, 12.5, INK, d.FONT_HEAD)
        d.add_text(s, 8.1, y + 0.36, 2.2, 0.2, sub, 7.5, GRAY)

    d.footer(s, 2)
    notes(s, "Дерево технологий: Orbita делится на Flutter-клиент и Node.js-сервер. "
             "Flutter работает на Dart, а Node.js — на своей экосистеме: Express, Socket.IO и npm. "
             "Дальше разберём каждую часть.")


# --------------------------------------------------------------------------
# 3. Выбор технологий
# --------------------------------------------------------------------------
def stack_slide(prs):
    s = d.new_slide(prs)
    d.eyebrow(s, "02", "ВЫБОР ТЕХНОЛОГИЙ")
    headline(s, "Почему именно этот стек", size=38, h=0.8)
    d.add_text(s, 0.75, 1.66, 10.8, 0.5,
               "Один разработчик, один репозиторий, минимум движущихся частей. "
               "Стек выбирался под это.", 13.5, GRAY)

    cards = [
        ("flutter", "Flutter + Dart", "Один код — пять платформ. Горячая перезагрузка и widgets вместо боли."),
        ("node", "Node.js + Express", "Быстрый I/O, минимум магии и огромная экосистема."),
        ("redis", "Redis", "Коды, кулдауны и TTL. Всё, что должно жить недолго."),
        ("jwt", "JWT + bcryptjs", "Сессии без состояния, пароли с солью. Классика, которая работает."),
    ]
    cw, ch = 5.76, 1.72
    for i, (icon_key, title, desc) in enumerate(cards):
        row, col = divmod(i, 2)
        x = 0.75 + col * (cw + 0.31)
        y = 2.35 + row * (ch + 0.24)
        d.card(s, x, y, cw, ch)
        tech_icon(s, x + 0.25, y + 0.24, 0.62, icon_key)
        d.add_text(s, x + 1.02, y + 0.24, cw - 1.2, 0.3, title, 17, INK, d.FONT_HEAD)
        d.add_text(s, x + 1.02, y + 0.68, cw - 1.2, 0.8, desc, 12.3, GRAY, line_spacing=1.28)

    d.add_text(s, 0.9, 6.45, 10.6, 0.35,
               "PostgreSQL, E2E, Socket.IO и Firebase — следующие четыре слайда. Они заслужили.",
               12.5, HINT, d.FONT_HAND)
    d.footer(s, 3)
    notes(s, "Почему такой стек: Flutter даёт пять платформ из одного кода, Node.js — "
             "быстрый I/O и один язык на сервере, Redis хранит короткоживущие коды, "
             "JWT и bcrypt закрывают авторизацию.")


# --------------------------------------------------------------------------
# 4. Четыре всадника — Васнецов, подписи под каждым
# --------------------------------------------------------------------------
def horsemen_slide(prs):
    s = d.new_slide(prs, dark=True)
    d.picture(s, ASSETS / "four_horsemen_dark.jpg", 0, 0, w=13.333, h=7.5)

    labels = [
        ("PostgreSQL", 0.20, 2.55, NAVY),
        ("E2E-шифрование", 2.70, 2.28, PEACH),
        ("Socket.IO", 5.75, 2.12, SKY),
        ("Firebase", 9.10, 1.95, d.AMBER),
    ]
    for name, x, y, tint in labels:
        chip = d.rect(s, x, y, 2.25, 0.5, NAVY, d.RGBColor(0x6B, 0x7F, 0x92), radius=0.1)
        d.set_fill_alpha(chip, 0.78)
        d.circle(s, x + 0.15, y + 0.2, 0.1, tint)
        d.add_text(s, x + 0.34, y, 1.8, 0.5, name, 11.8, WHITE, d.FONT_HEAD,
                   anchor=MSO_ANCHOR.MIDDLE)

    notes(s, "Четыре всадника: PostgreSQL хранит данные, E2E-шифрование прячет текст, "
             "Socket.IO доставляет всё в реальном времени, Firebase будит телефон. "
             "Картина Васнецова 1887 года, общественное достояние; версия затемнена.")


# --------------------------------------------------------------------------
# 5–8. Технологии
# --------------------------------------------------------------------------
def tech_slide(prs, num, label, title, body, icon_key, tint, bullets, fact_runs, dark=False):
    s = d.new_slide(prs, dark=dark)
    if dark:
        glow = d.circle(s, 9.9, -1.6, 5.8, d.RGBColor(0x35, 0x49, 0x5D))
        d.set_fill_alpha(glow, 0.3)
    else:
        d.decor_ring(s)
    d.eyebrow(s, f"{num:02d}", label, dark=dark)
    headline(s, title, size=32, w=11.8, color=WHITE if dark else INK, h=1.25)

    tech_icon(s, 0.75, 2.22, 0.82, icon_key, dark=dark,
              tile_fill=PEACH if icon_key == "lock" else WHITE)
    d.add_text(s, 0.78, 3.28, 3.0, 0.22, "ОБЩИЙ ОБЗОР", 8,
               SKY if not dark else d.RGBColor(0x8F, 0xB3, 0xCC), spc=160)
    d.add_text(s, 0.78, 3.56, 4.85, 2.0, body, 14.2,
               d.GRAY if not dark else d.DARK_TEXT, line_spacing=1.38)

    card_fill = WHITE if not dark else d.NAVY_SOFT
    card_line = BORDER if not dark else d.RGBColor(0x4A, 0x5E, 0x72)
    d.card(s, 6.05, 2.2, 6.53, 3.7, card_fill, card_line)
    d.add_text(s, 6.35, 2.44, 3.0, 0.22, "В ORBITA", 8,
               SKY if not dark else d.RGBColor(0x8F, 0xB3, 0xCC), spc=160)
    for i, text in enumerate(bullets):
        y = 2.82 + i * 0.66
        d.circle(s, 6.36, y + 0.1, 0.1, tint)
        d.add_text(s, 6.6, y, 5.65, 0.58, text, 12.3,
                   d.INK if not dark else d.RGBColor(0xE6, 0xEC, 0xF2), line_spacing=1.2)

    strip_fill = NAVY if not dark else d.PEACH_SOFT
    d.rect(s, 0.75, 6.06, 11.83, 0.64, strip_fill, radius=0.09)
    d.add_runs(s, 1.05, 6.06, 11.2, 0.64, fact_runs, size=13.5,
               anchor=MSO_ANCHOR.MIDDLE)
    d.footer(s, num + 1, dark=dark)
    return s


def postgres_slide(prs):
    s = tech_slide(
        prs, 4, "POSTGRESQL", "PostgreSQL: надёжный шкаф для всей переписки.",
        "Это база данных. Представь большой шкаф с полками: на одной — люди, "
        "на другой — чаты, на третьей — сообщения. PostgreSQL хранит всё аккуратно "
        "и не даёт полкам перепутаться.",
        "postgres", NAVY,
        [
            "Пять таблиц: люди, профили, чаты, участники и сообщения.",
            "Двенадцать миграций: база обновляется по шагам.",
            "Индексы работают как оглавление — история находится быстро.",
            "Связи между таблицами не дают данным потеряться.",
        ],
        [
            ("5", {"color": WHITE, "bold": True}), (" таблиц данных   ·   ", {"color": WHITE}),
            ("12", {"color": WHITE, "bold": True}), (" миграций   ·   ", {"color": WHITE}),
            ("0", {"color": PEACH, "bold": True}), (" ORM", {"color": WHITE}),
        ],
    )
    s.notes_slide.notes_text_frame.text = (
        "PostgreSQL — это шкаф с полками. Пять таблиц данных, двенадцать миграций, "
        "чистый SQL без ORM. Индексы как оглавление, внешние ключи не дают данным потеряться."
    )


def e2e_slide(prs):
    s = tech_slide(
        prs, 5, "E2E-ШИФРОВАНИЕ", "E2E: запечатанный конверт, который несёт сервер.",
        "Сквозное шифрование работает как конверт: ты запечатываешь сообщение "
        "у себя, сервер несёт его, а открыть может только получатель. "
        "Даже у меня нет ключа.",
        "lock", d.PEACH,
        [
            "Ключи создаются на телефоне и остаются там.",
            "У каждого сообщения — свой ключ.",
            "Сервер видит только набор символов.",
            "Прочитать может только адресат.",
        ],
        [
            ("Сервер видит шифротекст ", {"color": d.RGBColor(0x8A, 0x4A, 0x33)}),
            ("— и ничего больше.", {"color": d.RGBColor(0xC9, 0x6A, 0x4A), "bold": True}),
        ],
        dark=True,
    )
    s.notes_slide.notes_text_frame.text = (
        "E2E — это запечатанный конверт. Ключи создаются на устройстве, у каждого сообщения "
        "свой ключ, сервер видит только шифротекст. Расшифровать может только получатель."
    )


def socket_slide(prs):
    s = d.new_slide(prs)
    d.decor_ring(s)
    d.eyebrow(s, "06", "SOCKET.IO")
    headline(s, "Socket.IO: кто что слушает.", size=36, h=0.8)
    d.add_text(s, 0.75, 1.58, 10.5, 0.4,
               "Слева — события. Галочка показывает, какой экран их обрабатывает.",
               12.5, GRAY)

    card_x, card_y, card_w = 0.75, 2.12, 11.83
    d.card(s, card_x, card_y, card_w, 3.95)

    cols = [card_x + 0.3, card_x + 7.15, card_x + 9.45]
    header_y = card_y + 0.02
    d.rect(s, card_x, card_y, card_w, 0.5, NAVY, radius=0.08)
    d.add_text(s, cols[0], header_y, 5.0, 0.5, "СОБЫТИЕ", 8, d.RGBColor(0x8F, 0xB3, 0xCC),
               spc=160, anchor=MSO_ANCHOR.MIDDLE)
    d.add_text(s, cols[1], header_y, 1.9, 0.5, "ГЛАВНАЯ", 8, d.RGBColor(0x8F, 0xB3, 0xCC),
               spc=160, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    d.add_text(s, cols[2], header_y, 1.9, 0.5, "ЧАТ", 8, d.RGBColor(0x8F, 0xB3, 0xCC),
               spc=160, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)

    rows = [
        ("message_added", True, True),
        ("message_edited", True, True),
        ("message_deleted", True, True),
        ("message_status_updated", True, True),
        ("user_status_changed", True, True),
        ("chat_created", True, False),
        ("chat_deleted", True, False),
        ("user_typing", False, True),
        ("send_message · typing · mark_as_read", False, True),
    ]
    y = card_y + 0.66
    for i, (event, home, chat) in enumerate(rows):
        if i:
            d.line(s, card_x + 0.25, y - 0.06, card_x + card_w - 0.25, y - 0.06,
                   d.RGBColor(0xED, 0xF2, 0xF6), 0.75)
        d.add_text(s, cols[0], y, 6.4, 0.28, event, 11.2, INK, bold=True,
                   anchor=MSO_ANCHOR.MIDDLE)
        for cx, value in ((cols[1], home), (cols[2], chat)):
            if value:
                d.circle(s, cx + 0.82, y + 0.04, 0.2, d.GREEN)
                d.add_text(s, cx + 0.82, y + 0.04, 0.2, 0.2, "✓", 8, WHITE,
                           align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
            else:
                d.add_text(s, cx + 0.8, y, 0.25, 0.28, "—", 12, HINT,
                           align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        y += 0.37

    d.add_text(s, 0.9, 6.32, 10.8, 0.3,
               "7 входящих событий на главной  ·  6 в чате  ·  0 кнопок «обновить»",
               12.5, d.RGBColor(0xC9, 0x6A, 0x4A), d.FONT_HAND)
    d.footer(s, 7)
    notes(s, "Главная слушает семь событий: сообщения, статусы, создание и удаление чатов. "
             "Чат — шесть: те же сообщения и статусы плюс «печатает». "
             "Отправка и отметки о прочтении — тоже через сокет.")


def firebase_slide(prs):
    s = tech_slide(
        prs, 7, "FIREBASE", "Firebase: будильник, который стучится в телефон.",
        "Firebase Cloud Messaging — облачный push для Android и iOS. Доставляет "
        "уведомление, даже когда приложение закрыто.",
        "firebase", d.AMBER,
        [
            "FCM-токен привязан к аккаунту и обновляется.",
            "В push — имя отправителя, текст или тип вложения, аватар.",
            "Не беспокоит, если чат открыт или замьючен.",
            "Тап открывает чат; выход отвязывает токен.",
        ],
        [
            ("collapseKey", {"color": d.RGBColor(0xC9, 0x6A, 0x4A), "bold": True}),
            (" на чат: сто сообщений — одно уведомление.", {"color": d.RGBColor(0x8A, 0x4A, 0x33)}),
        ],
        dark=True,
    )
    s.notes_slide.notes_text_frame.text = (
        "Firebase Cloud Messaging: токен устройства живёт в users.fcm_token. "
        "Push уходит с именем отправителя, текстом или типом вложения и аватаром. "
        "Если чат открыт или замьючен — не уходит. collapseKey схлопывает пачку сообщений."
    )


# --------------------------------------------------------------------------
# 9. Путь одного сообщения
# --------------------------------------------------------------------------
def message_path_slide(prs):
    s = d.new_slide(prs)
    d.decor_ring(s)
    d.eyebrow(s, "08", "ПУТЬ СООБЩЕНИЯ")
    headline(s, "Путь одного сообщения.", size=36, h=0.8)
    d.add_text(s, 0.75, 1.58, 10.6, 0.4,
               "От нажатия «отправить» до расшифровки на другом телефоне.",
               12.5, GRAY)

    steps = [
        ("01", "Текст", "Пишешь на телефоне.", "✍️", d.SKY_SOFT),
        ("02", "Конверт", "Текст превращается в шифротекст.", "🔐", d.PEACH_SOFT),
        ("03", "Сокет", "Принимает и рассылает.", "⚡", d.AMBER_SOFT),
        ("04", "База", "Хранит историю.", "🗄️", d.GREEN_SOFT),
        ("05", "Экран", "Расшифровывает.", "📱", d.LILAC_SOFT),
    ]
    cw, gap = 2.15, 0.21
    for i, (num, title, desc, emoji, tint) in enumerate(steps):
        x = 0.75 + i * (cw + gap)
        d.card(s, x, 2.2, cw, 2.45)
        d.add_text(s, x + 0.18, 2.38, 0.5, 0.22, num, 9, PEACH, bold=True, spc=50)
        d.add_text(s, x + 0.18, 2.72, cw - 0.36, 0.3, title, 15.5, INK, d.FONT_HEAD)
        d.add_text(s, x + 0.18, 3.12, cw - 0.34, 0.9, desc, 10.2, GRAY, line_spacing=1.3)
        d.icon_badge(s, x + 0.18, 3.98, 0.52, emoji, tint, 17)
        if i < 4:
            d.add_text(s, x + cw + 0.01, 3.15, 0.19, 0.32, "→", 18, SKY,
                       align=PP_ALIGN.CENTER)

    d.rect(s, 0.75, 5.02, 11.83, 0.72, NAVY, radius=0.09)
    d.add_text(s, 1.05, 5.02, 11.2, 0.72,
               "Если получатель офлайн — Firebase присылает push, и телефон просыпается.",
               12.8, WHITE, anchor=MSO_ANCHOR.MIDDLE)
    d.add_text(s, 0.9, 6.08, 9.5, 0.35,
               "Сервер не открывает конверт ни на одном шаге.", 13, HINT, d.FONT_HAND)
    d.footer(s, 9)
    notes(s, "Путь сообщения: телефон шифрует, Socket.IO принимает, PostgreSQL сохраняет, "
             "получатель расшифровывает. Если он офлайн — Firebase отправляет push. "
             "Сервер всё это время видит только конверт.")


# --------------------------------------------------------------------------
# 10. Что видит сервер
# --------------------------------------------------------------------------
def server_view_slide(prs):
    s = d.new_slide(prs, dark=True)
    d.eyebrow(s, "09", "ПРИВАТНОСТЬ", dark=True)
    headline(s, "Что видит сервер.", size=38, color=WHITE, h=0.8)
    d.add_text(s, 0.75, 1.58, 10.6, 0.4,
               "Короткая правда о сквозном шифровании.", 12.5, d.DARK_TEXT)

    card_x, card_y, card_w = 0.75, 2.15, 11.83
    d.card(s, card_x, card_y, card_w, 3.55, d.NAVY_SOFT, d.RGBColor(0x4A, 0x5E, 0x72))
    d.rect(s, card_x, card_y, card_w, 0.52, d.RGBColor(0x3A, 0x4C, 0x60), radius=0.08)
    cols = [1.05, 4.1, 6.8, 9.5]
    heads = ["ПАРАМЕТР", "ТЕЛЕФОН", "СЕРВЕР", "БАЗА"]
    for x, text in zip(cols, heads):
        d.add_text(s, x, card_y, 2.4, 0.52, text, 7.8, d.RGBColor(0x8F, 0xB3, 0xCC),
                   spc=140, anchor=MSO_ANCHOR.MIDDLE)

    rows = [
        ("Текст", "открытый", "шифротекст", "шифротекст"),
        ("Ключи", "приватный", "публичный", "публичный"),
        ("Автор", "знает", "знает", "sender_id"),
        ("Время", "знает", "знает", "time_create"),
        ("Медиа", "файл", "файл", "URL"),
    ]
    y = card_y + 0.64
    for i, (name, phone, server, db) in enumerate(rows):
        if i:
            d.line(s, card_x + 0.25, y - 0.04, card_x + card_w - 0.25, y - 0.04,
                   d.RGBColor(0x4A, 0x5E, 0x72), 0.6)
        d.add_text(s, cols[0], y, 2.9, 0.22, name, 10.8, WHITE, bold=True)
        d.add_text(s, cols[1], y, 2.5, 0.22, phone, 10.2, d.RGBColor(0xA8, 0xDD, 0xB5))
        d.add_text(s, cols[2], y, 2.5, 0.22, server, 10.2, PEACH)
        d.add_text(s, cols[3], y, 2.5, 0.22, db, 10.2, d.DARK_TEXT)
        y += 0.56

    d.rect(s, 0.75, 5.98, 11.83, 0.62, d.PEACH_SOFT, radius=0.09)
    d.add_text(s, 1.05, 5.98, 11.2, 0.62,
               "Сервер знает, кто и когда. Не знает — что.",
               14, d.RGBColor(0x8A, 0x4A, 0x33), anchor=MSO_ANCHOR.MIDDLE)
    d.add_text(s, 0.9, 6.72, 10.0, 0.2,
               "Медиа пока без E2E — это следующий шаг.", 7.2, d.DARK_MUTED)
    d.footer(s, 10, dark=True)
    notes(s, "Телефон видит открытый текст и приватный ключ. Сервер и база — только "
             "шифротекст, публичный ключ и метаданные: кто, когда, какой чат. "
             "Медиа пока хранится без E2E — это следующий шаг.")


# --------------------------------------------------------------------------
# 11. Тесты и CI
# --------------------------------------------------------------------------
def tests_slide(prs):
    s = d.new_slide(prs)
    d.decor_ring(s)
    d.eyebrow(s, "10", "КАЧЕСТВО")
    headline(s, "Тесты, миграции и CI.", size=38, h=0.8)
    d.add_text(s, 0.75, 1.6, 10.8, 0.4,
               "Как проект не разваливается, когда я меняю одну строчку.", 12.5, GRAY)

    stats = [("2 124", "строки тестов"), ("12", "миграций"), ("5", "шагов CI")]
    for i, (num, label) in enumerate(stats):
        x = 0.75 + i * 3.95
        d.card(s, x, 2.18, 3.7, 1.28)
        d.add_text(s, x + 0.28, 2.32, 3.1, 0.5, num, 30, INK, d.FONT_HEAD)
        d.add_text(s, x + 0.28, 2.86, 3.1, 0.25, label, 10.5, GRAY)

    pipeline = [
        ("push", NAVY, WHITE),
        ("migrate", SKY, WHITE),
        ("npm test", d.GREEN, WHITE),
        ("flutter analyze", d.AMBER, NAVY),
        ("flutter test", PEACH, WHITE),
    ]
    px = 1.35
    for i, (text, fill, color) in enumerate(pipeline):
        d.rect(s, px, 4.12, 1.9, 0.58, fill, radius=0.1)
        d.add_text(s, px, 4.12, 1.9, 0.58, text, 9.5, color, d.FONT_HEAD,
                   align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        if i < len(pipeline) - 1:
            d.add_text(s, px + 1.9, 4.2, 0.25, 0.3, "→", 15, HINT,
                       align=PP_ALIGN.CENTER)
        px += 2.14

    d.add_text(s, 0.9, 5.15, 10.8, 0.35,
               "Каждый push и PR: миграции → тесты бэкенда → анализатор → тесты клиента.",
               11.5, GRAY)
    d.add_text(s, 0.9, 6.0, 8.6, 0.35,
               "Красный CI — не повод мержить.", 14, HINT, d.FONT_HAND)
    d.footer(s, 11)
    notes(s, "Две тысячи сто двадцать четыре строки тестов: шестьсот тридцать во Flutter "
             "и тысяча четыреста девяносто четыре на бэкенде. Плюс двенадцать миграций. "
             "CI на каждый push прогоняет миграции, тесты и анализатор.")


# --------------------------------------------------------------------------
# 12. Конкуренты
# --------------------------------------------------------------------------
def competitors_slide(prs):
    s = d.new_slide(prs)
    d.eyebrow(s, "13", "КОНТЕКСТ")
    headline(s, "Orbita на фоне больших.", size=36, h=0.8)
    d.add_text(s, 0.75, 1.58, 10.6, 0.4,
               "Без маркетинга: что у кого есть, а чего нет.", 12.5, GRAY)

    card_x, card_y, card_w = 0.75, 2.1, 11.83
    d.card(s, card_x, card_y, card_w, 3.6)
    d.rect(s, card_x, card_y, card_w, 0.55, NAVY, radius=0.08)
    cols = [0.95, 3.45, 5.73, 8.01, 10.29]
    heads = ["КРИТЕРИЙ", "TELEGRAM", "WHATSAPP", "SIGNAL", "ORBITA"]
    for x, text in zip(cols, heads):
        d.add_text(s, x, card_y, 2.2, 0.55, text, 7.8,
                   PEACH if text == "ORBITA" else d.RGBColor(0x8F, 0xB3, 0xCC),
                   spc=120, anchor=MSO_ANCHOR.MIDDLE)

    d.rect(s, 10.15, card_y + 0.55, 2.43, 3.05, d.PEACH_SOFT)
    rows = [
        ("E2E по умолчанию", "Secret Chats", "да", "да", "да"),
        ("Реклама", "в каналах", "—", "—", "—"),
        ("Открытый код", "частично", "—", "да", "—"),
        ("Свой сервер", "—", "—", "—", "да"),
        ("Цена", "0 ₽", "0 ₽", "0 ₽", "0 ₽"),
    ]
    y = card_y + 0.68
    for i, (name, tg, wa, sig, orb) in enumerate(rows):
        if i:
            d.line(s, card_x + 0.2, y - 0.04, card_x + card_w - 0.2, y - 0.04, BORDER, 0.6)
        d.add_text(s, cols[0], y, 2.4, 0.24, name, 10.3, INK, bold=True)
        for x, value in zip(cols[1:], (tg, wa, sig, orb)):
            is_orbit = x == cols[4]
            d.add_text(s, x, y, 2.15, 0.24, value,
                       9.6, d.RGBColor(0x8A, 0x4A, 0x33) if is_orbit else GRAY,
                       bold=is_orbit, align=PP_ALIGN.CENTER)
        y += 0.55

    d.add_text(s, 0.9, 6.3, 10.6, 0.3,
               "По публичным данным, без юридических тонкостей.", 7.5, HINT)
    d.footer(s, 14)
    notes(s, "Telegram шифрует только Secret Chats, WhatsApp и Signal — по умолчанию. "
             "Реклама есть в каналах Telegram. Открытый код — у Signal. Свой сервер — "
             "у Orbita. Цена у всех — ноль.")


# --------------------------------------------------------------------------
# 13. Ошибки, которые научили
# --------------------------------------------------------------------------
def mistakes_slide(prs):
    s = d.new_slide(prs, dark=True)
    d.eyebrow(s, "13", "ОШИБКИ", dark=True)
    headline(s, "Три бага, которые научили большему, чем курсы.", size=31,
             w=11.4, color=WHITE, h=1.3)

    cards = [
        ("01", "JWT-секрет",
         "Подпись публичной строкой — токен мог выпустить кто угодно.",
         "Обязательный секрет 32+ символа, иначе сервер не стартует.",
         "Безопасность по умолчанию"),
        ("02", "Ключи E2E",
         "Пара генерировалась заново — старая переписка ломалась.",
         "Ключи сохраняются на устройстве и переживают перезапуск.",
         "Данные важнее удобства"),
        ("03", "Кэш прочтений",
         "SQLite на части устройств не знал json_extract.",
         "JSON разбирается в Dart, статусы обновляются.",
         "Не доверяй платформе"),
    ]
    for i, (num, title, before, after, lesson) in enumerate(cards):
        x = 0.75 + i * 3.8
        d.card(s, x, 2.1, 3.55, 3.95, d.NAVY_SOFT, d.RGBColor(0x4A, 0x5E, 0x72))
        d.add_text(s, x + 0.24, 2.28, 0.5, 0.2, num, 8.5, PEACH, bold=True, spc=50)
        d.add_text(s, x + 0.24, 2.55, 3.0, 0.3, title, 15.5, WHITE, d.FONT_HEAD)
        d.add_text(s, x + 0.24, 3.02, 3.0, 0.18, "БЫЛО", 7, HINT, spc=120)
        d.add_text(s, x + 0.24, 3.22, 3.05, 0.75, before, 10.2, d.DARK_MUTED, line_spacing=1.25)
        d.add_text(s, x + 0.24, 4.02, 3.0, 0.18, "СТАЛО", 7, PEACH, spc=120)
        d.add_text(s, x + 0.24, 4.22, 3.05, 0.75, after, 10.2, WHITE, line_spacing=1.25)
        d.add_text(s, x + 0.24, 5.45, 3.05, 0.4, lesson, 8.3, d.RGBColor(0x8F, 0xB3, 0xCC),
                   d.FONT_HAND)

    d.add_text(s, 0.9, 6.35, 9.0, 0.35,
               "Хороший баг — тот, после которого появился тест.", 14, HINT, d.FONT_HAND)
    d.footer(s, 14, dark=True)
    notes(s, "Три реальных бага: публичный JWT-секрет, потеря ключей E2E и кэш статусов "
             "прочтения, который падал на части SQLite. Каждый закончился не только фиксом, "
             "но и тестом.")


# --------------------------------------------------------------------------
# 14. Экономика одного разработчика
# --------------------------------------------------------------------------
def economics_slide(prs):
    s = d.new_slide(prs)
    d.eyebrow(s, "15", "ЭКОНОМИКА")
    headline(s, "Сколько стоит свой мессенджер.", size=36, h=0.8)
    d.add_text(s, 0.75, 1.6, 10.6, 0.4, "Без инвесторов и бизнес-плана.", 12.5, GRAY)

    cards = [
        ("1", "VPS", "сервер"),
        ("0 ₽", "реклама", "и не планируется"),
        ("0 ₽", "подписки", "навсегда"),
        ("1", "разработчик", "и он же поддержка"),
        ("5", "платформ", "из одного кода"),
        ("∞", "бессонные ночи", "бесплатно"),
    ]
    for i, (num, label, sub) in enumerate(cards):
        row, col = divmod(i, 3)
        x = 0.75 + col * 3.95
        y = 2.18 + row * 1.78
        d.card(s, x, y, 3.72, 1.52)
        d.add_text(s, x + 0.25, y + 0.18, 3.2, 0.55, num, 30, PEACH if num in ("0 ₽", "∞") else INK,
                   d.FONT_HEAD)
        d.add_text(s, x + 0.25, y + 0.82, 3.2, 0.25, label, 12.5, INK, d.FONT_HEAD)
        d.add_text(s, x + 0.25, y + 1.12, 3.2, 0.22, sub, 8.5, GRAY)

    d.add_text(s, 0.9, 6.0, 9.6, 0.35,
               "Инвестиции: вечера, выходные и немного упрямства.", 14, HINT, d.FONT_HAND)
    d.footer(s, 16)
    notes(s, "Один VPS, один домен, ноль рекламы и подписок, один разработчик. "
             "Пять платформ из одного кода. Бессонные ночи — бесплатно.")


# --------------------------------------------------------------------------
# 15. Чего пока нет
# --------------------------------------------------------------------------
def limits_slide(prs):
    s = d.new_slide(prs)
    d.decor_ring(s)
    d.eyebrow(s, "14", "ЧЕСТНО")
    headline(s, "Чего пока нет.", size=38, h=0.8)
    d.add_text(s, 0.75, 1.6, 10.6, 0.4,
               "Лучше сказать вслух, чем делать вид.", 12.5, GRAY)

    items = [
        ("Групповые чаты", "Пока только один на один."),
        ("Звонки", "Текст и голосовые, без гудков."),
        ("Реакции", "Сердечко — отдельным сообщением."),
        ("Мультиустройство", "Один телефон — один я."),
    ]
    for i, (title, desc) in enumerate(items):
        x = 0.75 + i * 2.97
        d.card(s, x, 2.0, 2.8, 1.95)
        d.add_text(s, x + 0.22, 2.18, 2.35, 0.3, title, 14.5, INK, d.FONT_HEAD)
        d.add_text(s, x + 0.22, 2.6, 2.35, 0.75, desc, 10.2, GRAY, line_spacing=1.3)
        d.pill(s, x + 0.22, 3.48, 1.15, 0.3, "пока нет", d.PEACH_SOFT,
               d.RGBColor(0x8A, 0x4A, 0x33), 8.5)

    d.add_text(s, 0.75, 4.24, 4.0, 0.2, "ПУТЬ К 1.0", 8, SKY, spc=160)
    d.line(s, 1.25, 4.98, 10.35, 4.98, d.RGBColor(0xD5, 0xE1, 0xEB), 2.5)
    d.line(s, 1.25, 4.98, 1.6, 4.98, PEACH, 3.0)
    d.add_text(s, 10.4, 4.86, 0.3, 0.26, "→", 17, SKY, align=PP_ALIGN.CENTER)
    d.add_text(s, 10.88, 4.84, 0.4, 0.3, "🏁", 13, HINT)

    roadmap = [
        (1.55, "СЕЙЧАС", "0.8.13", "Бета: личные чаты, E2E, медиа и push.", True),
        (4.35, "ДАЛЬШЕ", "0.9", "Группы и звонки.", False),
        (7.15, "ПОТОМ", "0.10", "Реакции и мультиустройство.", False),
        (9.95, "РЕЛИЗ", "1.0", "Secure storage, E2E-медиа, масштабирование.", False),
    ]
    for x, stage, version, desc, current in roadmap:
        d.add_text(s, x - 0.1, 4.53, 2.4, 0.2, stage, 8.2,
                   PEACH if current else SKY, bold=True, spc=120)
        circle = d.circle(s, x, 4.82, 0.32, PEACH if current else PAPER,
                          PEACH if current else SKY, 2.0)
        if not current:
            d.circle(s, x + 0.1, 4.92, 0.12, SKY)
        d.add_text(s, x - 0.12, 5.28, 2.35, 0.3, version, 16,
                   d.RGBColor(0xC9, 0x6A, 0x4A) if current else INK, d.FONT_HEAD)
        d.add_text(s, x - 0.12, 5.64, 2.35, 0.7, desc, 9.2, GRAY, line_spacing=1.25)

    d.add_text(s, 0.9, 6.4, 9.4, 0.3,
               "Без обещаний по датам — только по версиям.", 12, HINT, d.FONT_HAND)
    d.footer(s, 15)
    notes(s, "Путь к релизу: 0.8.13 — текущая бета с личными чатами и E2E. "
             "0.9 — группы и звонки. 0.10 — реакции и мультиустройство. "
             "1.0 — secure storage, E2E для медиа и масштабирование. "
             "Без дат: один разработчик, но с понятными шагами.")


# --------------------------------------------------------------------------
# 16. Статистика кода
# --------------------------------------------------------------------------
def stats_slide(prs):
    s = d.new_slide(prs)
    d.decor_ring(s)
    d.eyebrow(s, "11", "СТАТИСТИКА")
    headline(s, "20 892 строки, которые я написал.", size=38, h=0.8)
    d.add_text(s, 0.75, 1.66, 11.0, 0.45,
               "Только мой код: без node_modules, build и сгенерированных файлов.",
               13, GRAY)

    stats = [
        ("20 892", "строк кода"),
        ("637 488", "символов"),
        ("3", "языка: Dart, JS, SQL"),
        ("≈ 350", "страниц, если распечатать"),
    ]
    col_w = 2.85
    for i, (num, label) in enumerate(stats):
        x = 0.75 + i * (col_w + 0.12)
        if i:
            d.line(s, x - 0.15, 2.28, x - 0.15, 3.5, BORDER, 1.0)
        d.add_text(s, x, 2.24, col_w - 0.1, 0.7, num, 38, INK, d.FONT_HEAD)
        d.add_text(s, x, 2.98, col_w - 0.1, 0.5, label, 10.5, GRAY, line_spacing=1.15)

    bars = [("Flutter", 14431, SKY), ("Бэкенд", 5643, d.GREEN),
            ("Тесты", 630, HINT), ("SQL", 188, d.AMBER)]
    max_val = 14431
    bx, bw = 3.35, 7.0
    y = 4.3
    for label, value, tint in bars:
        d.add_text(s, 0.75, y - 0.02, 2.4, 0.3, label, 12, INK)
        d.rect(s, bx, y, bw, 0.32, d.RGBColor(0xE8, 0xEE, 0xF4), radius=0.06)
        d.rect(s, bx, y, bw * value / max_val, 0.32, tint, radius=0.06)
        d.add_text(s, 10.55, y - 0.02, 1.3, 0.3, f"{value:,}".replace(",", " "),
                   11.5, GRAY, align=PP_ALIGN.RIGHT)
        y += 0.52

    d.footer(s, 12)
    notes(s, "Двадцать тысяч восемьсот девяносто две строки. Если распечатать — "
             "примерно триста пятьдесят страниц. Больше всего кода во Flutter, "
             "дальше бэкенд, тесты и SQL.")


# --------------------------------------------------------------------------
# 10. Масштаб: код против книг
# --------------------------------------------------------------------------
def books_slide(prs):
    s = d.new_slide(prs)
    d.eyebrow(s, "12", "МАСШТАБ")
    headline(s, "Код против книг.", size=40, h=0.8)
    d.add_text(s, 0.75, 1.62, 8.6, 0.4,
               "637 488 символов. Для сравнения — восемь книг, от Онегина до «Войны и мира».",
               12.3, GRAY)

    books = [
        ("Война и мир", 2_800_000, "≈ 2,8 млн"),
        ("Тихий Дон", 1_300_000, "≈ 1,3 млн"),
        ("Преступление и наказание", 1_000_000, "≈ 1,0 млн"),
        ("Мастер и Маргарита", 747_531, "747 531"),
        ("Orbita · код", 637_488, "637 488"),
        ("Гарри Поттер и философский камень", 450_000, "≈ 450 000"),
        ("Портрет Дориана Грея", 250_000, "≈ 250 000"),
        ("Евгений Онегин", 110_000, "≈ 110 000"),
    ]
    max_val = 2_800_000
    bx, bw = 3.55, 4.7
    y = 2.3
    for name, value, label in books:
        is_code = name.startswith("Orbita")
        d.add_text(s, 0.75, y - 0.01, 2.65, 0.4, name, 10.2 if not is_code else 10.4,
                   INK if is_code else GRAY, d.FONT_HEAD if is_code else d.FONT, line_spacing=1.0)
        d.rect(s, bx, y, bw, 0.34, d.RGBColor(0xEE, 0xF3, 0xF7), radius=0.06)
        d.rect(s, bx, y, max(0.06, bw * value / max_val), 0.34,
               PEACH if is_code else d.RGBColor(0xD8, 0xE2, 0xEC), radius=0.06)
        d.add_text(s, 8.35, y - 0.01, 0.75, 0.3, label, 9,
                   d.RGBColor(0xC9, 0x6A, 0x4A) if is_code else GRAY,
                   bold=is_code, align=PP_ALIGN.RIGHT)
        y += 0.5

    # Панель с деталями
    d.card(s, 9.25, 2.24, 3.33, 3.95, d.NAVY, d.NAVY)
    d.add_text(s, 9.55, 2.48, 2.8, 0.2, "ЕСЛИ РАСПЕЧАТАТЬ", 7.5,
               d.RGBColor(0x8F, 0xB3, 0xCC), spc=160)
    d.add_text(s, 9.55, 2.75, 2.7, 0.7, "≈ 350", 38, WHITE, d.FONT_HEAD)
    d.add_text(s, 9.55, 3.45, 2.7, 0.3, "страниц", 11, d.DARK_TEXT)
    d.line(s, 9.55, 3.78, 12.25, 3.78, d.DARK_LINE, 0.75)
    details = [
        ("85%", "«Мастера и Маргариты»"),
        ("64%", "«Преступления и наказания»"),
        ("49%", "«Тихого Дона»"),
        ("23%", "«Войны и мира»"),
        ("2,5×", "«Дориана Грея»"),
    ]
    yy = 3.95
    for value, name in details:
        d.add_text(s, 9.55, yy, 0.65, 0.25, value, 13.5, PEACH, d.FONT_HEAD)
        d.add_text(s, 10.25, yy + 0.03, 1.95, 0.4, name, 8.2, d.DARK_TEXT, line_spacing=1.1)
        yy += 0.43

    d.add_text(s, 9.55, 6.34, 3.0, 0.3,
               "Объёмы книг округлены. Код — точный.", 7.2, d.DARK_MUTED)
    d.footer(s, 13)
    notes(s, "Шестьсот тридцать семь тысяч символов — это примерно триста пятьдесят страниц. "
             "Восемьдесят пять процентов «Мастера и Маргариты», почти две трети "
             "«Преступления и наказания», половина «Тихого Дона» и меньше четверти "
             "«Войны и мира». «Дориана Грея» код больше в два с половиной раза. "
             "Цифры по книгам приблизительные, код точный.")


# --------------------------------------------------------------------------
# 11. Финал
# --------------------------------------------------------------------------
def final_slide(prs):
    s = d.new_slide(prs, dark=True)
    d.eyebrow(s, "P.S.", "ФИНАЛ", dark=True)
    headline(s, "Это не просто код.\nЭто работающий мессенджер.", y=1.75, size=36,
             w=7.6, color=WHITE, h=1.55)
    d.add_text(s, 0.9, 3.35, 7.0, 0.8,
               "Orbita 0.8.13: личные чаты, E2E, медиа и push.\n"
               "Один разработчик, пять платформ, ноль рекламы.",
               15.5, d.DARK_TEXT, line_spacing=1.35)
    d.add_text(s, 0.9, 4.6, 7.2, 0.3,
               "Flutter · Node.js · PostgreSQL · Socket.IO · Firebase",
               10.5, d.DARK_MUTED, spc=40)
    d.add_text(s, 0.9, 5.35, 6.0, 0.8,
               "Спасибо, что дослушали.\nДальше — только код и тесты.",
               19, PEACH, d.FONT_HAND, line_spacing=1.2)
    app_mark(s, 8.8, 1.9, 4.0)
    notes(s, "Спасибо. Orbita — это двадцать тысяч строк, четыре всадника и один разработчик. "
             "Личные чаты, E2E, медиа и push уже работают. Дальше — группы, звонки и реакции.")


# --------------------------------------------------------------------------
# Анимации: плавное появление объектов + переход Fade
# --------------------------------------------------------------------------
def add_transition(slide):
    sld = slide._element
    for tag in ("p:transition", "p:timing"):
        old = sld.find(qn(tag))
        if old is not None:
            sld.remove(old)
    transition = etree.SubElement(sld, qn("p:transition"))
    transition.set("spd", "med")
    etree.SubElement(transition, qn("p:fade"))


def animation_shapes(slide):
    result = []
    for sh in slide.shapes:
        if sh.top is None or sh.width is None:
            continue
        if sh.top < 0:
            continue
        if sh.top >= Inches(7.0):
            continue
        if sh.width >= Inches(12.9) and sh.height >= Inches(6.9) and not hasattr(sh, "image"):
            continue
        result.append(sh)
    return result


def add_animations(slide):
    add_transition(slide)
    shapes = animation_shapes(slide)
    if not shapes:
        return

    sld = slide._element
    timing = etree.SubElement(sld, qn("p:timing"))
    tn = etree.SubElement(timing, qn("p:tnLst"))
    root_par = etree.SubElement(tn, qn("p:par"))
    root = etree.SubElement(root_par, qn("p:cTn"))
    root.set("id", "1")
    root.set("dur", "indefinite")
    root.set("restart", "never")
    root.set("nodeType", "tmRoot")
    root_child = etree.SubElement(root, qn("p:childTnLst"))
    seq = etree.SubElement(root_child, qn("p:seq"))
    seq.set("concurrent", "1")
    seq.set("nextAc", "seek")
    seq_tn = etree.SubElement(seq, qn("p:cTn"))
    seq_tn.set("id", "2")
    seq_tn.set("dur", "indefinite")
    seq_tn.set("nodeType", "mainSeq")
    seq_child = etree.SubElement(seq_tn, qn("p:childTnLst"))

    par3 = etree.SubElement(seq_child, qn("p:par"))
    c3 = etree.SubElement(par3, qn("p:cTn"))
    c3.set("id", "3")
    c3.set("fill", "hold")
    st3 = etree.SubElement(c3, qn("p:stCondLst"))
    cond3 = etree.SubElement(st3, qn("p:cond"))
    cond3.set("delay", "0")
    c3_child = etree.SubElement(c3, qn("p:childTnLst"))

    par4 = etree.SubElement(c3_child, qn("p:par"))
    c4 = etree.SubElement(par4, qn("p:cTn"))
    c4.set("id", "4")
    c4.set("fill", "hold")
    st4 = etree.SubElement(c4, qn("p:stCondLst"))
    cond4 = etree.SubElement(st4, qn("p:cond"))
    cond4.set("delay", "0")
    c4_child = etree.SubElement(c4, qn("p:childTnLst"))

    nid = 5
    base_top = min(sh.top for sh in shapes)
    for sh in shapes:
        band = min(8, int((sh.top - base_top) / Inches(0.38)))
        delay = band * 110

        epar = etree.SubElement(c4_child, qn("p:par"))
        ectn = etree.SubElement(epar, qn("p:cTn"))
        ectn.set("id", str(nid))
        ectn.set("presetID", "10")
        ectn.set("presetClass", "entr")
        ectn.set("presetSubtype", "0")
        ectn.set("fill", "hold")
        ectn.set("grpId", "0")
        ectn.set("nodeType", "withEffect")
        est = etree.SubElement(ectn, qn("p:stCondLst"))
        econd = etree.SubElement(est, qn("p:cond"))
        econd.set("delay", str(delay))
        echild = etree.SubElement(ectn, qn("p:childTnLst"))

        set_el = etree.SubElement(echild, qn("p:set"))
        cb = etree.SubElement(set_el, qn("p:cBhvr"))
        sctn = etree.SubElement(cb, qn("p:cTn"))
        sctn.set("id", str(nid + 1))
        sctn.set("dur", "1")
        sctn.set("fill", "hold")
        sst = etree.SubElement(sctn, qn("p:stCondLst"))
        scond = etree.SubElement(sst, qn("p:cond"))
        scond.set("delay", "0")
        tgt = etree.SubElement(cb, qn("p:tgtEl"))
        spt = etree.SubElement(tgt, qn("p:spTgt"))
        spt.set("spid", str(sh.shape_id))
        attrs = etree.SubElement(cb, qn("p:attrNameLst"))
        an = etree.SubElement(attrs, qn("p:attrName"))
        an.text = "style.visibility"
        to = etree.SubElement(set_el, qn("p:to"))
        val = etree.SubElement(to, qn("p:strVal"))
        val.set("val", "visible")

        anim = etree.SubElement(echild, qn("p:animEffect"))
        anim.set("transition", "in")
        anim.set("filter", "fade")
        acb = etree.SubElement(anim, qn("p:cBhvr"))
        actn = etree.SubElement(acb, qn("p:cTn"))
        actn.set("id", str(nid + 2))
        actn.set("dur", "500")
        atgt = etree.SubElement(acb, qn("p:tgtEl"))
        aspt = etree.SubElement(atgt, qn("p:spTgt"))
        aspt.set("spid", str(sh.shape_id))
        nid += 3

    prev = etree.SubElement(seq, qn("p:prevCondLst"))
    pc = etree.SubElement(prev, qn("p:cond"))
    pc.set("evt", "onPrev")
    pc.set("delay", "0")
    pt = etree.SubElement(pc, qn("p:tgtEl"))
    etree.SubElement(pt, qn("p:sldTgt"))
    nxt = etree.SubElement(seq, qn("p:nextCondLst"))
    nc = etree.SubElement(nxt, qn("p:cond"))
    nc.set("evt", "onNext")
    nc.set("delay", "0")
    nt = etree.SubElement(nc, qn("p:tgtEl"))
    etree.SubElement(nt, qn("p:sldTgt"))


def main():
    prs = Presentation()
    prs.slide_width = Inches(W)
    prs.slide_height = Inches(H)
    prs.core_properties.title = "Orbita — технический разбор"
    prs.core_properties.author = "Твой разработчик"
    prs.core_properties.subject = "Как устроен мессенджер Orbita"

    title_slide(prs)
    overview_slide(prs)
    stack_slide(prs)
    horsemen_slide(prs)
    postgres_slide(prs)
    e2e_slide(prs)
    socket_slide(prs)
    firebase_slide(prs)
    message_path_slide(prs)
    server_view_slide(prs)
    tests_slide(prs)
    stats_slide(prs)
    books_slide(prs)
    mistakes_slide(prs)
    limits_slide(prs)
    final_slide(prs)

    for s in prs.slides:
        add_animations(s)

    prs.save(OUT)
    print(f"saved {OUT} ({len(prs.slides)} slides)")


if __name__ == "__main__":
    main()
