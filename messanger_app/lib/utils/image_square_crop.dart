import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Обрезка аватара квадратом без внешних пакетов.
///
/// Картинка уменьшается до [size] px, поэтому на сервер уходит лёгкий файл,
/// а в шапке профиля нет «сплющенного» фото.
class ImageSquareCrop {
  const ImageSquareCrop._();

  static Future<File> crop(File source, {int size = 512}) async {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final side = math.min(image.width, image.height).toDouble();
    final left = (image.width - side) / 2;
    final top = (image.height - side) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(left, top, side, side),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    );

    final cropped = await recorder.endRecording().toImage(size, size);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    cropped.dispose();

    if (data == null) {
      throw Exception('Не удалось обрезать изображение');
    }

    final output = File(
      '${source.parent.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(data.buffer.asUint8List());
    return output;
  }
}
