import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'log_service.dart';

class LeaderboardEntry {
  final int score;
  final DateTime date;

  const LeaderboardEntry({required this.score, required this.date});

  Map<String, dynamic> toJson() => {
        'score': score,
        'date': date.toIso8601String(),
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        score: json['score'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

class LeaderboardService {
  static const _key = 'leaderboard';
  static const int _maxEntries = 20;

  static Future<List<LeaderboardEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LogService.warning('排行榜数据解析失败: $e');
      return [];
    }
  }

  static Future<void> addScore(int score) async {
    if (score <= 0) return;
    final entries = await getEntries();
    entries.add(LeaderboardEntry(score: score, date: DateTime.now()));
    entries.sort((a, b) => b.score.compareTo(a.score));
    final trimmed = entries.take(_maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
    LogService.info('排行榜: 新增分数 $score');
  }

  static Future<int> getHighScore() async {
    final entries = await getEntries();
    return entries.isEmpty ? 0 : entries.first.score;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    LogService.info('排行榜已清空');
  }
}
