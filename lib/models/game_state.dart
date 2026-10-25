import 'difficulty.dart';
import 'obstacle.dart';
import 'pickup.dart';
import 'rider_motion.dart';

enum GameStatus { idle, playing, paused, over }

/// 一局骑行的完整快照。
///
/// 规则由 GameProvider 持有；Flame 每帧读取该快照做渲染，
/// Flutter HUD 只监听节流后的通知。
class GameState {
  final GameStatus status;
  final Difficulty difficulty;

  /// 已骑行距离（米），1 米 = 10 世界单位。
  final double distance;

  /// 小鱼与连击带来的额外分数；总分 = 距离 + bonusScore。
  final int bonusScore;

  final int fish;
  final int highScore;
  final double bestDistance;
  final double speed;

  final RiderMotion rider;
  final int shieldCharges;
  final double magnetRemaining;
  final double invulnerable;

  final int combo;
  final double comboTimer;

  final List<Obstacle> obstacles;
  final List<Pickup> pickups;

  const GameState({
    this.status = GameStatus.idle,
    this.difficulty = Difficulty.normal,
    this.distance = 0,
    this.bonusScore = 0,
    this.fish = 0,
    this.highScore = 0,
    this.bestDistance = 0,
    this.speed = 27.5,
    this.rider = RiderMotion.grounded,
    this.shieldCharges = 0,
    this.magnetRemaining = 0,
    this.invulnerable = 0,
    this.combo = 1,
    this.comboTimer = 0,
    this.obstacles = const <Obstacle>[],
    this.pickups = const <Pickup>[],
  });

  bool get isPlaying => status == GameStatus.playing;
  bool get isPaused => status == GameStatus.paused;
  bool get isOver => status == GameStatus.over;
  bool get isIdle => status == GameStatus.idle;

  int get score => distance.floor() + bonusScore;

  bool get hasShield => shieldCharges > 0;
  bool get magnetActive => magnetRemaining > 0;
  bool get invulnerableActive => invulnerable > 0;

  GameState copyWith({
    GameStatus? status,
    Difficulty? difficulty,
    double? distance,
    int? bonusScore,
    int? fish,
    int? highScore,
    double? bestDistance,
    double? speed,
    RiderMotion? rider,
    int? shieldCharges,
    double? magnetRemaining,
    double? invulnerable,
    int? combo,
    double? comboTimer,
    List<Obstacle>? obstacles,
    List<Pickup>? pickups,
  }) {
    return GameState(
      status: status ?? this.status,
      difficulty: difficulty ?? this.difficulty,
      distance: distance ?? this.distance,
      bonusScore: bonusScore ?? this.bonusScore,
      fish: fish ?? this.fish,
      highScore: highScore ?? this.highScore,
      bestDistance: bestDistance ?? this.bestDistance,
      speed: speed ?? this.speed,
      rider: rider ?? this.rider,
      shieldCharges: shieldCharges ?? this.shieldCharges,
      magnetRemaining: magnetRemaining ?? this.magnetRemaining,
      invulnerable: invulnerable ?? this.invulnerable,
      combo: combo ?? this.combo,
      comboTimer: comboTimer ?? this.comboTimer,
      obstacles: obstacles ?? this.obstacles,
      pickups: pickups ?? this.pickups,
    );
  }
}
