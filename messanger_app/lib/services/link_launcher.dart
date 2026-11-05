import 'dart:io';

import 'package:flutter/services.dart';

class LinkLauncher {
  const LinkLauncher._();

  static const MethodChannel _channel = MethodChannel('orbita/links');

  static Future<bool> open(String url) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return _openOnDesktop(url);
    }

    try {
      final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _openOnDesktop(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.start('cmd', [
          '/c',
          'start',
          '',
          url,
        ], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [url], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
