import 'package:bird_on_a_bike/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeaderboardEntry', () {
    test('toJson 与 fromJson 往返一致', () {
      final entry = LeaderboardEntry(
        score: 100,
        date: DateTime(2026, 6, 21, 12),
      );
      final restored = LeaderboardEntry.fromJson(entry.toJson());
      expect(restored.score, 100);
      expect(restored.date, DateTime(2026, 6, 21, 12));
    });

    test('toJson 包含 score 和 date', () {
      final entry = LeaderboardEntry(score: 50, date: DateTime(2026, 1, 1));
      final json = entry.toJson();
      expect(json['score'], 50);
      expect(json['date'], isA<String>());
    });

    test('fromJson 正确解析', () {
      final entry = LeaderboardEntry.fromJson({
        'score': 200,
        'date': '2026-06-21T12:00:00.000',
      });
      expect(entry.score, 200);
      expect(entry.date.year, 2026);
    });

    test('零分条目仍可序列化', () {
      final entry = LeaderboardEntry(score: 0, date: DateTime(2026, 6, 21));
      expect(entry.score, 0);
      expect(entry.toJson()['score'], 0);
    });
  });
}
