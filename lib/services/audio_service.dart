import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'log_service.dart';

/// 预生成音效的（频率, 时长毫秒）组合。
const List<(int, int)> _toneSpecs = <(int, int)>[
  (520, 80),
  (700, 90),
  (740, 70),
  (820, 70),
  (900, 70),
  (980, 70),
  (1060, 70),
  (1040, 110),
  (300, 150),
  (180, 220),
  (120, 420),
  (440, 60),
];

/// 在后台 isolate 里跑一段合成任务；Web 没有 isolate，退回当前线程。
Future<T> _runOffThread<T>(T Function() task) {
  if (kIsWeb) return Future<T>.value(task());
  return Isolate.run(task);
}

Map<String, Uint8List> _buildToneWavs() => <String, Uint8List>{
      for (final spec in _toneSpecs)
        '${spec.$1}:${spec.$2}': _wavForTone(spec.$1, spec.$2),
    };

Uint8List _wavForTone(int freq, int durationMs) {
  const sampleRate = 22050;
  final numSamples = (sampleRate * durationMs / 1000).round();
  return _buildWav(sampleRate, numSamples, (i) {
    final t = i / sampleRate;
    final envelope = 1.0 - (i / numSamples);
    return sin(2 * pi * freq * t) * envelope * 0.3;
  });
}

/// 轻快的海边小循环：4 个音符 × 2 组，配上低音根音。
Uint8List _bgmLoopWav() {
  const sampleRate = 22050;
  const durationMs = 8000;
  const noteDuration = 0.5;
  const melody = [392.00, 493.88, 587.33, 523.25, 440.00, 493.88, 587.33, 659.25];
  const bassRoot = 196.00;
  const numSamples = sampleRate * durationMs ~/ 1000;
  return _buildWav(sampleRate, numSamples, (i) {
    final t = i / sampleRate;
    final noteIndex = (t / noteDuration).floor() % melody.length;
    final noteT = t % noteDuration;
    final envelope = sin(pi * noteT / noteDuration);
    final lead = sin(2 * pi * melody[noteIndex] * t) * envelope * 0.07;
    final bass = sin(2 * pi * bassRoot * t) * 0.025;
    final shimmer = sin(2 * pi * melody[noteIndex] * 2 * t) * envelope * 0.02;
    return lead + bass + shimmer;
  });
}

Uint8List _buildWav(
  int sampleRate,
  int numSamples,
  double Function(int index) sampleAt,
) {
  const channels = 1;
  const bitsPerSample = 16;
  final dataSize = numSamples * channels * (bitsPerSample ~/ 8);
  final fileSize = 44 + dataSize;
  final buffer = ByteData(fileSize);
  var offset = 0;

  void writeStr(String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset++, s.codeUnitAt(i));
    }
  }

  void writeUint16(int v) {
    buffer.setUint16(offset, v, Endian.little);
    offset += 2;
  }

  void writeUint32(int v) {
    buffer.setUint32(offset, v, Endian.little);
    offset += 4;
  }

  // RIFF header
  writeStr('RIFF');
  writeUint32(fileSize - 8);
  writeStr('WAVE');

  // fmt chunk
  writeStr('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(sampleRate * channels * (bitsPerSample ~/ 8));
  writeUint16(channels * (bitsPerSample ~/ 8));
  writeUint16(bitsPerSample);

  // data chunk
  writeStr('data');
  writeUint32(dataSize);

  for (var i = 0; i < numSamples; i++) {
    final sample =
        (sampleAt(i) * 32767).round().clamp(-32768, 32767).toInt();
    buffer.setInt16(offset, sample, Endian.little);
    offset += 2;
  }

  return buffer.buffer.asUint8List();
}

/// 程序化生成音效与背景音乐，不依赖外部音频资源。
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final _player = AudioPlayer();
  final _bgmPlayer = AudioPlayer();
  final Map<String, Uint8List> _toneCache = {};
  Uint8List? _bgmLoop;
  bool _muted = false;
  bool _bgmRequested = false;
  bool _bgmPlaying = false;

  bool get muted => _muted;

  void setMuted(bool v) {
    _muted = v;
    LogService.info('音效: ${v ? "静音" : "开启"}');
    if (!_bgmRequested) return;
    if (v) {
      _guard(_bgmPlayer.pause());
    } else if (_bgmPlaying) {
      _guard(_bgmPlayer.resume());
    } else {
      unawaited(startBgm());
    }
  }

  /// 预生成常用音效并预热播放器，避免第一次跳跃时卡顿。
  ///
  /// 合成放到后台 isolate，主线程只接收字节数组；否则 12 个音效加 8 秒
  /// BGM 会在启动后第一帧占住主线程。
  Future<void> prewarm() async {
    _guard(_player.setVolume(1.0));
    try {
      _toneCache.addAll(await _runOffThread(_buildToneWavs));
    } catch (e) {
      LogService.warning('音效预生成失败: $e');
    }
    await _ensureBgm();
  }

  /// 开始循环播放背景音乐；静音时只记录请求，取消静音后再播放。
  Future<void> startBgm() async {
    _bgmRequested = true;
    if (_muted || _bgmPlaying) return;
    await _ensureBgm();
    if (_muted || _bgmPlaying) return;
    await _guard(_playBgm());
  }

  /// 按需生成 BGM：优先后台 isolate，失败时退回当前线程。
  Future<Uint8List> _ensureBgm() async {
    final cached = _bgmLoop;
    if (cached != null) return cached;
    try {
      final wav = await _runOffThread(_bgmLoopWav);
      _bgmLoop = wav;
      return wav;
    } catch (e) {
      LogService.warning('背景音乐生成失败: $e');
      final wav = _bgmLoopWav();
      _bgmLoop = wav;
      return wav;
    }
  }

  Future<void> playJump({bool doubleJump = false}) async {
    if (_muted) return;
    await _playTone(doubleJump ? 700 : 520, doubleJump ? 90 : 80);
  }

  Future<void> playFish(int combo) async {
    if (_muted) return;
    final freq = 660 + min(combo, 5) * 80;
    await _playTone(freq, 70);
  }

  Future<void> playPowerUp() async {
    if (_muted) return;
    await _playTone(740, 90);
    await Future.delayed(const Duration(milliseconds: 70));
    await _playTone(1040, 110);
  }

  Future<void> playShieldBreak() async {
    if (_muted) return;
    await _playTone(300, 150);
  }

  Future<void> playCrash() async {
    if (_muted) return;
    await _playTone(180, 220);
    await Future.delayed(const Duration(milliseconds: 90));
    await _playTone(120, 420);
  }

  Future<void> playTick() async {
    if (_muted) return;
    await _playTone(440, 60);
  }

  Future<void> _playTone(int freq, int durationMs) async {
    try {
      await _player.play(BytesSource(_tone(freq, durationMs)));
    } catch (e) {
      LogService.warning('音效播放失败: $e');
    }
  }

  Future<void> _playBgm() async {
    if (!_bgmRequested || _muted) return;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.3);
      await _bgmPlayer.play(BytesSource(_bgmLoop!));
      _bgmPlaying = true;
    } catch (e) {
      _bgmPlaying = false;
      LogService.warning('背景音乐播放失败: $e');
    }
  }

  Future<void> _guard(Future<void> future) async {
    try {
      await future;
    } catch (e) {
      LogService.warning('音效操作失败: $e');
    }
  }

  Uint8List _tone(int freq, int durationMs) {
    return _toneCache.putIfAbsent(
      '$freq:$durationMs',
      () => _wavForTone(freq, durationMs),
    );
  }

  void dispose() {
    _player.dispose();
    _bgmPlayer.dispose();
  }
}
