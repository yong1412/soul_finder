import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  UserProfile? _currentUser;
  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;

  UserProfile? get currentUser => _currentUser;

  bool get isInitializing => _isInitializing;

  bool get isBusy => _isBusy;

  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    try {
      _currentUser = await _service.restoreSession();
      _errorMessage = null;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _currentUser = null;
    } catch (_) {
      _errorMessage = 'Unable to restore your login session.';
      _currentUser = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(
      String email,
      String password,
      ) async {
    return _execute(() async {
      _currentUser = await _service.login(
        email,
        password,
      );
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
    required String lookingFor,
    required List<String> interests,
    double? heightCm,
    double? weightKg,
  }) async {
    return _execute(() async {
      _currentUser = await _service.register(
        email: email,
        password: password,
        name: name,
        age: age,
        gender: gender,
        lookingFor: lookingFor,
        interests: interests,
        heightCm: heightCm,
        weightKg: weightKg,
      );
    });
  }

  Future<bool> updateProfile(
      UserProfile profile,
      ) async {
    return _execute(() async {
      _currentUser = await _service.updateUser(
        profile,
      );
    });
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final uid = _currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _currentUser = _currentUser?.copyWith(isOnline: isOnline);
    notifyListeners();

    await _service.updateOnlineStatusDirect(uid, isOnline);
  }

  Future<bool> setHideOnlineStatus(bool hide) async {
    return _execute(() async {
      _currentUser = await _service.setHideOnlineStatus(hide);
    });
  }

  Future<bool> setRadarMode(String modeStr) async {
    return _execute(() async {
      _currentUser = await _service.setRadarMode(modeStr);
    });
  }

  Future<bool> changePassword(
      String newPassword,
      ) async {
    return _execute(() async {
      await _service.changePassword(
        newPassword,
      );
    });
  }

  Future<void> logout() async {
    final uid = _currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      // ⚪ Mark user as OFFLINE in Firestore BEFORE signing out!
      try {
        await _service.updateOnlineStatusDirect(uid, false);
      } catch (e) {
        debugPrint("Notice updating offline status on logout: $e");
      }
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.logout();
      _currentUser = null;
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage =
      'Unable to sign out. Please try again.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    final user = _currentUser;

    if (user == null) {
      _errorMessage = 'No user is currently signed in.';
      notifyListeners();
      return false;
    }

    try {
      await _service.updateOnlineStatusDirect(user.uid, false);
    } catch (_) {}

    return _execute(() async {
      await _service.deleteUser(
        user.email,
      );

      _currentUser = null;
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _execute(
      Future<void> Function() operation,
      ) async {
    if (_isBusy) {
      return false;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await operation();
      return true;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (error) {
      debugPrint(
        'Authentication error: $error',
      );

      _errorMessage =
      'Something went wrong. Please try again.';

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}