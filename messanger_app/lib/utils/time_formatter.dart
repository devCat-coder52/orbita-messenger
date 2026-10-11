class TimeFormatter {
  const TimeFormatter._();

  static const List<String> monthsGenitive = [
    '',
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String time(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String chatListTime(DateTime dateTime, {DateTime? now}) {
    now ??= DateTime.now();
    if (isSameDay(dateTime, now)) return time(dateTime);
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  static String dateHeader(DateTime dateTime, {DateTime? now}) {
    now ??= DateTime.now();
    if (isSameDay(dateTime, now)) return 'Сегодня';
    if (isSameDay(dateTime, now.subtract(const Duration(days: 1)))) {
      return 'Вчера';
    }
    if (dateTime.year == now.year) {
      return '${dateTime.day} ${monthsGenitive[dateTime.month]}';
    } else {
      return '${dateTime.day} ${monthsGenitive[dateTime.month]} ${dateTime.year}';
    }
  }

  static String fullDate(DateTime dateTime) =>
      '${dateTime.day} ${monthsGenitive[dateTime.month]} ${dateTime.year}';

  static String relative(DateTime dateTime, {DateTime? now}) {
    now ??= DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    return dateHeader(dateTime, now: now);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
