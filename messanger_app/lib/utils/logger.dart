import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Логи приложения: в debug — подробные, в release — только важное.
///
/// ProductionFilter пропускает только warning/error, поэтому info/debug
/// не засоряют консоль бета-сборки.
final Logger log = Logger(
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  printer: kReleaseMode
      ? SimplePrinter(colors: false)
      : PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
        ),
);
