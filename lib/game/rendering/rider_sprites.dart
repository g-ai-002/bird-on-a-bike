import 'dart:math' as math;
import 'dart:ui';

import '../painting/pelican_art.dart';

/// 骑行者身上随曲柄角度变化的部件缓存。
///
/// 车轮、曲柄、双腿与踏板每帧都要重画，而它们的形状只由曲柄角度决定。
/// 这里按 [steps] 档角度各烘焙一张 [Picture]，运行时按角度取整绘制，
/// 既保留矢量清晰度，又把每帧几十次 Path/Paint 构造变成几次贴图回放。
class RiderSpriteCache {
  RiderSpriteCache() {
    for (var i = 0; i < steps; i++) {
      final angle = i * math.pi * 2 / steps;
      final look = RideLook(wheelAngle: angle);
      _wheels.add(_record((canvas) => paintRiderWheels(canvas, look)));
      _cranks.add(_record((canvas) => paintRiderCranks(canvas, look)));
      _legsStand.add(_record((canvas) => paintRiderLegs(canvas, look)));
      _legsDuck.add(
        _record(
          (canvas) => paintRiderLegs(
            canvas,
            RideLook(wheelAngle: angle, ducking: true),
          ),
        ),
      );
      _pedals.add(_record((canvas) => paintRiderPedals(canvas, look)));
    }
  }

  static const int steps = 12;

  final List<Picture> _wheels = <Picture>[];
  final List<Picture> _cranks = <Picture>[];
  final List<Picture> _legsStand = <Picture>[];
  final List<Picture> _legsDuck = <Picture>[];
  final List<Picture> _pedals = <Picture>[];

  static Picture _record(void Function(Canvas canvas) painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas);
    return recorder.endRecording();
  }

  static int _index(double wheelAngle) {
    final step = (wheelAngle * steps / (math.pi * 2)).floor() % steps;
    return step < 0 ? step + steps : step;
  }

  void drawWheels(Canvas canvas, double wheelAngle) {
    canvas.drawPicture(_wheels[_index(wheelAngle)]);
  }

  void drawCranks(Canvas canvas, double wheelAngle) {
    canvas.drawPicture(_cranks[_index(wheelAngle)]);
  }

  void drawLegs(Canvas canvas, double wheelAngle, {required bool ducking}) {
    canvas.drawPicture(
      (ducking ? _legsDuck : _legsStand)[_index(wheelAngle)],
    );
  }

  void drawPedals(Canvas canvas, double wheelAngle) {
    canvas.drawPicture(_pedals[_index(wheelAngle)]);
  }

  void dispose() {
    for (final pictures in <List<Picture>>[
      _wheels,
      _cranks,
      _legsStand,
      _legsDuck,
      _pedals,
    ]) {
      for (final picture in pictures) {
        picture.dispose();
      }
      pictures.clear();
    }
  }
}
