import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PrefsStore {
  Future<bool> get onboarded;
  Future<void> setOnboarded(bool value);
}

class SharedPrefsStore implements PrefsStore {
  static const _kOnboarded = 'zuum.onboarded';

  @override
  Future<bool> get onboarded async =>
      SharedPreferences.getInstance().then((p) => p.getBool(_kOnboarded) ?? false);

  @override
  Future<void> setOnboarded(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, value);
  }
}

/// In-memory prefs for `ENV=mock` and widget tests.
class InMemoryPrefsStore implements PrefsStore {
  InMemoryPrefsStore({bool onboarded = false}) : _onboarded = onboarded;

  bool _onboarded;

  @override
  Future<bool> get onboarded async => _onboarded;

  @override
  Future<void> setOnboarded(bool value) async => _onboarded = value;
}
