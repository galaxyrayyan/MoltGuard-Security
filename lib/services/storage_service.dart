import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _key = 'molt_history_v3';

  Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = history.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(_key, historyList);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_key) ?? [];
      return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }
}
