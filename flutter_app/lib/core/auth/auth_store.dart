import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'xdu_treehole_auth_token';
  SharedPreferences? _prefs;
  String? _token;
  UserProfile? _currentUser;

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  UserProfile? get currentUser => _currentUser;

  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs?.getString(_tokenKey);
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _prefs?.setString(_tokenKey, token);
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _currentUser = null;
    await _prefs?.remove(_tokenKey);
    notifyListeners();
  }
}
