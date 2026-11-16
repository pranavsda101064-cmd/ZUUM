import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_api.dart';

enum AdminAuthStatus { booting, signedOut, signedIn }

class AdminAuth extends ChangeNotifier {
  AdminAuth({AdminApi? api}) : api = api ?? AdminApi() {
    this.api.onTokens = _persistTokens;
    this.api.onExpired = _expire;
  }

  final AdminApi api;

  AdminAuthStatus status = AdminAuthStatus.booting;
  AdminUser? user;
  String? error;
  bool busy = false;

  static const _kAccess = 'zuum.admin.access';
  static const _kRefresh = 'zuum.admin.refresh';
  static const _kUser = 'zuum.admin.user';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    final rawUser = prefs.getString(_kUser);
    if (access == null || access.isEmpty || rawUser == null) {
      status = AdminAuthStatus.signedOut;
      notifyListeners();
      return;
    }
    api.setSession(access: access, refresh: refresh);
    try {
      final me = await api.me();
      if (me.role != 'staff') {
        await _clear(prefs);
        status = AdminAuthStatus.signedOut;
        error = 'This dashboard is for Zuum ops staff only.';
      } else {
        user = me;
        status = AdminAuthStatus.signedIn;
      }
    } catch (_) {
      await _clear(prefs);
      status = AdminAuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> _persistTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
  }

  Future<void> _expire() async {
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    api.setSession();
    user = null;
    status = AdminAuthStatus.signedOut;
    error = 'Your session expired. Sign in again.';
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final session = await api.login(email, password);
      if (session.user.role != 'staff') {
        error = 'This dashboard is for Zuum ops staff only.';
        busy = false;
        notifyListeners();
        return false;
      }
      api.setSession(access: session.access, refresh: session.refresh);
      user = session.user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccess, session.access);
      await prefs.setString(_kRefresh, session.refresh);
      await prefs.setString(_kUser, jsonEncode(session.user.toJson()));
      status = AdminAuthStatus.signedIn;
      busy = false;
      notifyListeners();
      return true;
    } on AdminApiException catch (e) {
      error = e.message;
      busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      error = 'Could not sign in. Check your connection and try again.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    api.setSession();
    user = null;
    status = AdminAuthStatus.signedOut;
    error = null;
    notifyListeners();
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }
}

class AdminScope extends InheritedNotifier<AdminAuth> {
  const AdminScope({
    super.key,
    required AdminAuth auth,
    required super.child,
  }) : super(notifier: auth);

  static AdminAuth of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
    assert(scope != null, 'AdminScope missing');
    return scope!.notifier!;
  }
}
