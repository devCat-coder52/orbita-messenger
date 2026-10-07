import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String voiceUrl;
  final int durationSeconds;
  final bool isMe;
  final bool isLocal;

  const VoiceMessagePlayer({
    super.key,
    required this.voiceUrl,
    required this.durationSeconds,
    required this.isMe,
    this.isLocal = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  static const double _waveHeight = 28.0;

  final ap.AudioPlayer _player = ap.AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _completeSub;

  bool _isPlaying = false;
  double _progress = 0.0;
  int _totalMs = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.durationSeconds * 1000;
    _posSub = _player.onPositionChanged.listen((p) {
      if (_disposed || !mounted) return;
      final total = _totalMs > 0 ? _totalMs : 1;
      setState(() {
        _progress = (p.inMilliseconds / total).clamp(0.0, 1.0);
      });
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (_disposed || !mounted) return;
      setState(() {
        _isPlaying = false;
        _progress = 0.0;
      });
    });
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceUrl != widget.voiceUrl && _isPlaying) {
      _stop();
    }
  }

  String get _source {
    if (widget.isLocal || widget.voiceUrl.startsWith('temp:')) {
      final path = widget.voiceUrl.replaceFirst('temp:', '');
      return Uri.file(path).toString();
    }
    return '${dotenv.env['BASE_URL']}${widget.voiceUrl}';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    try {
      await _player.play(ap.UrlSource(_source));
      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось воспроизвести аудио: $e')),
        );
      }
    }
  }

  void _stop() {
    _player.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _progress = 0.0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _displayDuration {
    if (_isPlaying && _totalMs > 0) {
      final remaining = ((_totalMs * (1 - _progress)) / 1000).ceil();
      return remaining.clamp(0, _totalMs ~/ 1000);
    }
    return widget.durationSeconds;
  }

  Widget _buildWaveform(Color accentColor) {
    const amplitudes = [0.45, 0.75, 0.55, 0.95, 0.65, 0.85, 0.5, 0.7, 0.9, 0.6];
    return SizedBox(
      width: 135,
      height: _waveHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(amplitudes.length * 3, (i) {
          final a = amplitudes[i % amplitudes.length];
          final playedFraction = i / (amplitudes.length * 3);
          final isPlayed = playedFraction <= _progress;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 2.5,
              height: _waveHeight * a,
              decoration: BoxDecoration(
                color: isPlayed
                    ? accentColor
                    : accentColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).primaryColor;
    final textColor = widget.isMe ? Colors.black87 : Colors.black87;

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: accentColor,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildWaveform(accentColor),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_displayDuration),
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _posSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
