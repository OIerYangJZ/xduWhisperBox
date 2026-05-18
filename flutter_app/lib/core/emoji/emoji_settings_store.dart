import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emoji_catalog.dart';

class EmojiSettingsStore extends ChangeNotifier {
  EmojiSettingsStore._();

  static final EmojiSettingsStore instance = EmojiSettingsStore._();

  static const String _enabledKey = 'emoji_enabled';
  static const String _favoritesKey = 'emoji_favorites';

  static const int maxFavorites = 16;

  SharedPreferences? _prefs;
  bool _enabled = true;
  List<String> _favorites = List<String>.from(EmojiCatalog.defaultFavorites);

  bool get enabled => _enabled;
  List<String> get favorites => List<String>.unmodifiable(_favorites);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_enabledKey) ?? true;

    final List<String> savedFavorites =
        _prefs?.getStringList(_favoritesKey) ?? const <String>[];
    if (savedFavorites.isEmpty) {
      _favorites = List<String>.from(EmojiCatalog.defaultFavorites);
    } else {
      _favorites = savedFavorites
          .where((String item) => EmojiCatalog.all.contains(item))
          .toSet()
          .toList();
      if (_favorites.isEmpty) {
        _favorites = List<String>.from(EmojiCatalog.defaultFavorites);
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _prefs?.setBool(_enabledKey, enabled);
    notifyListeners();
  }

  Future<bool> toggleFavorite(String emoji) async {
    if (_favorites.contains(emoji)) {
      _favorites = _favorites.where((String item) => item != emoji).toList();
      if (_favorites.isEmpty) {
        _favorites = List<String>.from(EmojiCatalog.defaultFavorites);
      }
      await _prefs?.setStringList(_favoritesKey, _favorites);
      notifyListeners();
      return true;
    }

    if (_favorites.length >= maxFavorites) {
      return false;
    }
    _favorites = <String>[..._favorites, emoji];
    await _prefs?.setStringList(_favoritesKey, _favorites);
    notifyListeners();
    return true;
  }

  Future<void> resetDefaults() async {
    _enabled = true;
    _favorites = List<String>.from(EmojiCatalog.defaultFavorites);
    await _prefs?.setBool(_enabledKey, _enabled);
    await _prefs?.setStringList(_favoritesKey, _favorites);
    notifyListeners();
  }
}

void insertEmojiToController({
  required TextEditingController controller,
  required String emoji,
}) {
  final String text = controller.text;
  final TextSelection selection = controller.selection;
  final int start = selection.start >= 0 ? selection.start : text.length;
  final int end = selection.end >= 0 ? selection.end : text.length;
  final String newText = text.replaceRange(start, end, emoji);
  final int newOffset = start + emoji.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}
