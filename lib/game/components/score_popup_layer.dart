import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// 拾取时向上飘起的文字层。
class ScorePopupLayer extends Component {
  ScorePopupLayer({required Color color})
      : _baseColor = color,
        _style = TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        super(priority: 55);

  final Color _baseColor;
  final TextStyle _style;

  void show(
    Vector2 position,
    String text, {
    Color? color,
    double rise = 52,
    double fontSize = 18,
  }) {
    final paint = TextPaint(
      style: _style.copyWith(
        color: color ?? _baseColor,
        fontSize: fontSize,
      ),
    );
    final popup = TextComponent(
      text: text,
      textRenderer: paint,
      anchor: Anchor.center,
      position: position,
      priority: 55,
    );
    popup.add(
      MoveByEffect(
        Vector2(0, -rise),
        EffectController(duration: 0.75, curve: Curves.easeOut),
      ),
    );
    popup.add(RemoveEffect(delay: 0.75));
    add(popup);
  }

  void clear() {
    for (final child in children.toList()) {
      child.removeFromParent();
    }
  }
}
