import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Оверлей записи голосового сообщения (в стиле Telegram/WhatsApp):
/// зажать кнопку микрофона — запись, свайп вверх — отмена.
class VoiceRecordingOverlay extends StatefulWidget {
  final Future<void> Function(File file, int durationSeconds) onSend;
  final VoidCallback onFinished; // оверлей скрыт (отправка или отмена)

  const VoiceRecordingOverlay._({
    super.key,
    required this.onSend,
    required this.onFinished,
  });

  /// Вставляет полноэкранный оверлей записи поверх всего приложения.
  static void start(
    BuildContext context, {
    required Future<void> Function(File file, int durationSeconds) onSent,
  }) {
    late final OverlayEntry entry;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) =>
          VoiceRecordingOverlay._(onSend: onSent, onFinished: remove),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay> {
  static const int _maxDurationSeconds = 300; // 5 минут

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _isCancelling = false; // палец уведён в зону отмены
  bool _started = false;
  bool _finished = false;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showError(
          'Нет доступа к микрофону. Разрешите запись звука в настройках.',
        );
        widget.onFinished();
        return;
      }
      final dir = await getTemporaryDirectory();
      final recPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: recPath,
      );
      if (!mounted) return;
      setState(() => _started = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds += 1);
        if (_seconds >= _maxDurationSeconds) {
          _finish(send: true);
        }
      });
    } catch (e) {
      _showError('Не удалось начать запись: $e');
      widget.onFinished();
    }
  }

  Future<void> _finish({required bool send}) async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _timer = null;
    final elapsed = _seconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    widget.onFinished();

    if (!send || path == null) return;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0 || elapsed < 1) {
      if (mounted) _showError('Запись слишком короткая');
      return;
    }
    await widget.onSend(file, elapsed);
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _format(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (details) =>
            _dragStartY = details.globalPosition.dy,
        onVerticalDragUpdate: (details) {
          // Свайп вверх на ~80px от точки старта — режим отмены.
          final startY = _dragStartY ?? details.globalPosition.dy;
          final cancel = startY - details.globalPosition.dy > 80;
          if (cancel != _isCancelling && mounted) {
            setState(() => _isCancelling = cancel);
          }
        },
        onVerticalDragEnd: (_) {
          _finish(send: !_isCancelling);
        },
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _isCancelling ? Colors.red.shade700 : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCancelling ? Icons.delete_forever : Icons.mic,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isCancelling
                          ? 'Отпустите — отмена'
                          : 'Отпустите — отправить',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _started ? _format(_seconds) : 'подготовка…',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Свайп вверх — отменить',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
